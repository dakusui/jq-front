#!/bin/bash -eu
set -eu

_JF="${1:?Specify 'jf' to test in absolute path}"
_TEST_ROOT_DIR="${2:?Specify a directory in which test dirs are stored.}"
_TARGET_TESTS="${3:-*}"
_JF_PATH=.:${_TEST_ROOT_DIR}/base
JF_BASEDIR="$(dirname "$(dirname "${0}")")"
export JF_BASEDIR

function run_normal_test() {
  local _testfile="${1}"
  local _dirname
  local _diff
  local _ret=1
  _dirname="$(dirname ${_testfile})"
  ${_JF} "${_dirname}/input.json" >"${_dirname}/test-output".json || return 1
  {
    diff <(jq -S . "${_dirname}/expected.json") <(jq -S . "${_dirname}/test-output.json") >"${_dirname}/test-output.diff"
  }
  _diff=$(cat "${_dirname}/test-output.diff") || return 1
  if [[ -z ${_diff} ]]; then
    echo "PASSED" 1>&2
    _ret=0
  else
    _ret=1
    echo "FAILED: diff--->
    ${_diff}
    ---" 1>&2
  fi
  return ${_ret}
}

function _failure_message() {
  local _expected_validity_level="${1}"
  local _schema="${2}"
  local _expectation="${3}"
  echo "(Expectation:${_expected_validity_level}):Expected to be ${_expectation} with ${_schema} schema but not:'${_dirname/input.txt/}'" >&2
  cat "${_dirname}/test-output-${_schema}".txt >&2
}

function run_validation_test() {
  local _testfile="${1}"
  local _actual_strict
  local _actual_lenient
  local _expected_validity_level
  local _ret=0
  _expected_validity_level=$(jq -r -c ".expectation.validityLevel" "${_testfile}")
  _dirname="$(dirname ${_testfile})"
  ${_JF} "${_dirname}/input.json" -d --validation=lenient &>"${_dirname}/test-output-lenient".txt
  _actual_lenient=$?
  ${_JF} "${_dirname}/input.json" -d --validation=strict &>"${_dirname}/test-output-strict".txt
  _actual_strict=$?
  if [[ "${_expected_validity_level}" == "strict" ]]; then
    if [[ "${_actual_lenient}" != 0 ]]; then
      _failure_message "${_expected_validity_level}" "lenient" "valid"
      _ret=1
    fi
    if [[ "${_actual_strict}" != 0 ]]; then
      _failure_message "${_expected_validity_level}" "strict" "valid"
      _ret=1
    fi
  elif [[ "${_expected_validity_level}" == "lenient" ]]; then
    if [[ "${_actual_lenient}" != 0 ]]; then
      _failure_message "${_expected_validity_level}" "lenient" "valid"
      _ret=1
    fi
    if [[ "${_actual_strict}" == 0 ]]; then
      _failure_message "${_expected_validity_level}" "strict" "INVALID"
      _ret=1
    fi
  elif [[ "${_expected_validity_level}" == "invalid" ]]; then
    if [[ "${_actual_lenient}" == 0 ]]; then
      _failure_message "${_expected_validity_level}" "lenient" "INVALID"
      _ret=1
    fi
    if [[ "${_actual_strict}" == 0 ]]; then
      _failure_message "${_expected_validity_level}" "strict" "INVALID"
      _ret=1
    fi
  else
    echo "Unknown expectation validity level:'${_expected_validity_level}' was specified." 1>&2
    return 1
  fi
  if [[ ${_ret} == 0 ]]; then
    echo "PASSED" 1>&2
  else
    echo "FAILED" 1>&2
  fi
  return ${_ret}
}

function _run_testcase() {
  local _executor="${1}"
  shift
  bash "${_executor}" "${@}"
  return $?
}

function run_suite_test() {
  local _testfile="${1}"
  local _testfile_dir="${_testfile}"
  local _executor
  local _numtestcases
  local _numfailed=0
  local _ret=0
  _testfile_dir="$(dirname ${_testfile}"")"
  _executor="${_testfile_dir}/$(jq -r -c '.args.executor' "${_testfile}")"
  _numtestcases="$(jq -r -c '.args.testCases | length' ${_testfile})"
  echo "" >&2
  for i in $(seq 0 $((_numtestcases - 1))); do
    echo -n "  Running test case [${i}]" >&2
    # shellcheck disable=SC2046
    _run_testcase "${_executor}" $(jq -r -c ".args.testCases[${i}].args[]" "${_testfile}") || {
      _ret=1
      _numfailed=$((_numfailed + 1))
      echo "...FAILED" >&2
      continue
    }
    echo "...PASSED" >&2
  done
  echo "  ${_numfailed} test cases (out of ${_numtestcases}) have failed" >&2
  if [[ ${_ret} == 0 ]]; then
    echo "PASSED" 1>&2
  else
    echo "FAILED" 1>&2
  fi
  return ${_ret}
}

function runtest() {
  local _test_json="${1}"
  local _dirname="${_test_json%/test.json}"
  local _test_type
  _test_type="$(jq -r -c ".testType" "${_test_json}")" || return 1
  echo -n "executing test(${_test_type}):'${_dirname#${_TEST_ROOT_DIR}/}':..." >&2

  export JF_PATH
  JF_PATH=${_JF_PATH}:$(dirname "${_test_json}")
  "run_${_test_type}_test" "${_test_json}" || return 1
}

function clean() {
  find "${_TEST_ROOT_DIR}" -name 'test-output*' -exec rm {} \;
}

function main() {
  local failed=0
  local skipped=0
  local numtests=0
  echo "${_TEST_ROOT_DIR}" 1>&2
  while IFS= read -r -d '' i; do
    numtests=$((numtests + 1))
    if [[ "x${i}" == x${_TARGET_TESTS} ]]; then
      runtest "${i}" || failed=$((failed + 1))
    else
      skipped=$((skipped + 1))
      echo "Skipping ${i}" >&2
    fi
  done < <(find "${_TEST_ROOT_DIR}" -type f -name test.json -print0)

  if [[ $failed == 0 ]]; then
    echo "No test failed (total=${numtests}; skipped=${skipped})" >&2
  else
    echo "$failed test(s) FAILED (total=${numtests}; skipped=${skipped})" >&2
    return 1
  fi
}

clean || exit 1
main || exit 1
