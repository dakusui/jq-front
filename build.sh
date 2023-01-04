#!/usr/bin/env bash
# Run tests
set -eu

source build_info.sh

function _test_package() {
  local _version="${1}"
  local _target_tests="${2}"
  local _ret
  # shellcheck disable=SC1090
  # source=jf_aliases
  source "$(pwd)/${APP_NAME}_aliases"
  export -f jq-front
  export JF_DOCKER_TAG="${_version}"
  message "Testing package:'${JF_DOCKER_TAG}'"
  bash -eu "tests/tests.sh" "${APP_NAME}" "$(pwd)/tests" "${_target_tests}"
  _ret=$?
  unset -f jq-front
  unset JF_DOCKER_TAG
  return "${_ret}"
}

function _build() {
  local _version="${1}"
  docker build --build-arg VERSION="${_version}" -t "${DOCKER_REPO_NAME}:${_version}" .
}

function message() {
  local IFS=" "
  local _o
  _o="${1}"
  shift
  echo "${_o}" "$*" >&2
}

function execute_prepare() {
  local _content
  local _templated
  local _resource_dir="res"
  while IFS= read -r -d '' i; do
    local _src_file="${i}"
    local _dest_file="${_src_file#${_resource_dir}/}"
    _dest_file="${_dest_file#[0-9]*_}"
    message -n "Processing '${_src_file}'->'${_dest_file}'"
    mkdir -p "$(dirname "${_dest_file}")"
    # shellcheck disable=SC2002
    _content=$(cat "${_src_file}" | sed -E 's/\"/\\\"/g' | sed -E 's/`/\\`/g')
    _templated=$(eval "echo \"${_content}\"") || {
      message "Failed to process a file '${_src_file}'(content='$(head "${_src_file}")...')"
      return 1
    }
    echo "${_templated}" >"${_dest_file}"
    message "...done"
  done < <(find "${_resource_dir}" -type f -print0 | sort -z)
}

function execute_doc() {
  while IFS= read -r -d '' i; do
    local _src_file="${i}"
    message -n "Processing '${_src_file}'"
    docker run --rm \
      --user "$(id -u):$(id -g)" \
      -v "$(pwd)":/documents/ \
      asciidoctor/docker-asciidoctor \
      asciidoctor -r asciidoctor-diagram -a toc=left "${i}" -o "${i%.adoc}.html"
    message "...done"
  done < <(find "docs" -type f -name '*.adoc' -print0)
  message -n "Generating 'docs/index.html'"
  docs/index.sh >docs/index.html
  message "...done"
}

function execute_package() {
  _build "${TARGET_VERSION}-snapshot"
}

function execute_test() {
  local _target_tests="${1:-*}"
  bash -eu "tests/tests.sh" "$(pwd)/${APP_NAME}" "$(pwd)/tests" "${_target_tests}"
  return $?
}

function execute_test_package() {
  local _target_tests="${1:-*}"
  _test_package "${TARGET_VERSION}-snapshot" "${_target_tests}"
  return $?
}

function execute_check_release() {
  local uncommitted_changes
  local unmerged_commits
  local release_branch="master"
  local current_branch
  # shellcheck disable=SC2063
  current_branch=$(git branch | grep '^*' | cut -d ' ' -f 2)
  if [[ ${current_branch} != "${release_branch}" ]]; then
    message "You are not on release branch:'${release_branch}': current branch:'${current_branch}'"
    return 1
  fi
  uncommitted_changes=$(git diff)
  if [[ ! -z ${uncommitted_changes} ]]; then
    message "You have uncommitted changes"
    echo "${uncommitted_changes}" | less
    return 1
  fi
  git pull origin "${release_branch}"
  unmerged_commits=$(git log origin/${release_branch}..HEAD)
  if [[ ! -z ${unmerged_commits} ]]; then
    message "You have following unmerged commits against branch:'${release_branch}'"
    message "${unmerged_commits}"
    return 1
  fi
}

function execute_package_release() {
  _build "${TARGET_VERSION}"
  _build "latest"
}

function execute_test_release() {
  local _target_tests="${1:-*}"
  _test_package "${TARGET_VERSION}" "${_target_tests}"
}

function execute_release() {
  docker login
  docker push "${DOCKER_REPO_NAME}:${TARGET_VERSION}"
  docker push "${DOCKER_REPO_NAME}:latest"
}

function execute_post_release() {
  local tmp
  git tag "${TARGET_VERSION}"
  git push origin "${TARGET_VERSION}"
  tmp=$(mktemp --suffix=".jq-front.build")
  jq '.|.version.latestReleased.minor=.version.target.minor|.version.target.minor=.version.target.minor+1' build_info.json >"${tmp}" || abort "Failed to bump up the version."
  cp "${tmp}" build_info.json
  message "Updated build_info.json"
  source build_info.sh
  message "Reloaded build_info.sh"
  message "Synchronize documentation"
  execute_prepare
  execute_doc
  message "Documenatation was synchronized"
  git commit -a -m "$(printf "Bump up target version to v%s.%s" \
    "$(jq '.version.target.major' "${tmp}")" \
    "$(jq '.version.target.minor' "${tmp}")")" || abort "Failed to commit bumped up version."
  message "Committed the change"
  git push origin master:master || abort "Failed to push the change."
  message "Pushed it to the remote"
}

function execute_deploy() {
  docker login
  docker push "${DOCKER_REPO_NAME}:${TARGET_VERSION}-snapshot"
}

function execute_stage() {
  local _stage="${1}"
  shift
  message "EXECUTING:${_stage}..."
  {
    "execute_${_stage}" "$@" && message "DONE:${_stage}"
  } || {
    message "FAILED:${_stage}"
    return 1
  }
  return 0
}

function main() {
  if [[ $# == 0 ]]; then
    main doc test
    return 0
  fi
  if [[ ${1} == OSX ]]; then
    main doc package test_package
    return 0
  fi
  if [[ ${1} == PACKAGE ]]; then
    main doc test package test_package
    return 0
  fi
  if [[ ${1} == DEPLOY ]]; then
    main doc test package test_package deploy
    return 0
  elif [[ ${1} == RELEASE ]]; then
    main check_release doc test package_release test_release release post_release
    return 0
  fi

  local -a _stages=("prepare")
  _stages+=("$@")
  for i in "${_stages[@]}"; do
    local _args
    IFS=':' read -r -a _args <<<"${i}"
    execute_stage "${_args[@]}" || exit 1
  done
}

main "${@}"
