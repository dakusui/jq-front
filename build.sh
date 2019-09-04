# Run tests
set -eu

TARGET_VERSION=v0.2

function _test_package() {
  local _version="${1}"
  local _target_tests="${2}"
  # shellcheck disable=SC1090
  # source=jf_aliases
  source "$(pwd)/jf_aliases"
  export -f jf-docker
  export JF_DOCKER_TAG="${_version}"
  bash -eu "tests/tests.sh" "jf-docker" "$(pwd)/tests" "${_target_tests}"
  unset jf-docker
  unset JF_DOCKER_TAG
}

function _build() {
  local _version="${1}"
  docker build -t "dakusui/jf:${_version}" .
}

function message() {
  local _message="${1}"
  echo "${_message}" 1>&2
}

function execute_doc() {
  docker run -it \
    --rm \
    --user 1000:1000 \
    -v "$(pwd)":/documents/ \
    asciidoctor/docker-asciidoctor \
    asciidoctor -r asciidoctor-diagram README.adoc -o docs/index.html
}

function execute_package() {
  _build "latest"
}

function execute_test() {
  local _target_tests="${1:-*}"
  bash -eu "tests/tests.sh" "$(pwd)/jf" "$(pwd)/tests" "${_target_tests}"
}

function execute_test_package() {
  local _target_tests="${1:-*}"
  _test_package "latest" "${_target_tests}"
}

function execute_package_release() {
  _build "${TARGET_VERSION}"
}

function execute_release() {
  local uncommitted_changes
  local unmerged_commits
  local release_branch="master"
  local current_branch
  # shellcheck disable=SC2063
  current_branch=$(git branch|grep '^*'|cut -d ' ' -f 2)
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
  docker login
  docker push "dakusui/jf:${TARGET_VERSION}"
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
    main doc test package
  fi
  for i in "$@"; do
    local _args
    IFS=':' read -r -a _args <<<"${i}"
    execute_stage "${_args[@]}" || exit 1
  done
}

main "${@}"
