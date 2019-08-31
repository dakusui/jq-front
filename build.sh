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
  bash -eu "tests/tests.sh" "$(pwd)/jf" "$(pwd)/tests"
}

function execute_stage() {
  local _stage="${1}"
  message "EXECUTING:${_stage}..."
  {
    "execute_${_stage}" && message "DONE:${_stage}"
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
    execute_stage "${i}" || exit 1
  done
}

main "${@}"
