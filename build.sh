# Run tests
set -eu

function message() {
  local _message="${1}"
  echo "${_message}" 1>&2
}

function execute_doc() {
  docker run -it \
         --user 1000:1000 \
         -v "$(pwd)":/documents/ \
         asciidoctor/docker-asciidoctor \
         asciidoctor -r asciidoctor-diagram README.adoc -o docs/index.html
}

function execute_package() {
  docker build -t dakusui/jf .
}

function execute_test() {
  local _target_tests="${1:-*}"
  bash -eu "tests/tests.sh" "$(pwd)/jf" "$(pwd)/tests" "${_target_tests}"
}

function execute_test_package() {
  local _target_tests="${1:-*}"
  # shellcheck disable=SC1090
  # source=jf_alias
  source "$(pwd)/jf_aliases"
  export -f jf-docker
  export  JF_DOCKER_TAG=latest
  bash -eu "tests/tests.sh" "jf-docker" "$(pwd)/tests" "${_target_tests}"
}

function execute_release() {
  docker login
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
