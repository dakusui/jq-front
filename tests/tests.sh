#!/bin/bash -eu

_JF="${1:?Specify 'jf' to test in absolute path}"
_TEST_ROOT_DIR=${2:?Specify a directory in which test dirs are stored.}
JF_PATH=.:$(pwd)/base
export JF_PATH

function runtest() {
  local _dirname="${1}"
  local _diff
  local _ret=0
  echo -n "executing test:'${_dirname}':..."
  cd "${_dirname}"
  ${_JF} input.json > test-output.json
  diff <(jq -S . expected.json) <(jq -S . test-output.json) > test.diff
  _diff=$(cat test.diff)
  if [[ -z ${_diff} ]]; then
    echo "PASSED" >&2
  else
    _ret=1
    echo "FAILED: diff--->
    ${_diff}
    ---" >&2
  fi
  cd ..
  return ${_ret}
}

function main() {
  local failed
  failed=0
  for i in "${_TEST_ROOT_DIR}"/*; do
    if [[ ${i} == *base || -f "${i}" ]]; then
      continue
    fi
    runtest "${i}" || failed=$((${failed} + 1))
  done

  if [[ $failed == 0 ]]; then
    echo "all tests passed"
  else
    echo "$failed test(s) FAILED"
    return 1
  fi
}

main || exit 1