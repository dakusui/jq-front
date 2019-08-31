#!/bin/bash -eu
set -eu

_JF="${1:?Specify 'jf' to test in absolute path}"
_TEST_ROOT_DIR="${2:?Specify a directory in which test dirs are stored.}"
JF_PATH=.:${_TEST_ROOT_DIR}/base
export JF_PATH

function runtest() {
  local _dirname="${1%/input.json}"
  local _diff
  local _ret=1
  echo -n "executing test:'${_dirname}':..."
  ${_JF} "${_dirname}/input.json" > "${_dirname}/test-output".json || return 1
  diff <(jq -S . "${_dirname}/expected.json") <(jq -S . "${_dirname}/test-output.json") >\
   "${_dirname}/test-output.diff" || return 1
  _diff=$(cat "${_dirname}/test-output.diff")
  if [[ -z ${_diff} ]]; then
    echo "PASSED" >&2
    _ret=0
  else
    _ret=1
    echo "FAILED: diff--->
    ${_diff}
    ---" >&2
  fi
  return ${_ret}
}

function clean() {
  find "${_TEST_ROOT_DIR}" -name 'test-output*' -exec rm {} \;
}

function main() {
  local failed
  failed=0
  echo "${_TEST_ROOT_DIR}" 1>&2
  while IFS= read -r -d '' i
  do
    i="${i%/input.json}"
    if [[ ${i} == *base || -f "${i}" ]]; then
      continue
    fi
    runtest "${i}" || failed=$((${failed} + 1))
  done <   <(find "${_TEST_ROOT_DIR}" -type f -name input.json -print0)

  if [[ $failed == 0 ]]; then
    echo "all tests passed"
  else
    echo "$failed test(s) FAILED"
    return 1
  fi
}

clean || exit 1
main || exit 1