#!/usr/bin/env bash
set -eu

# shellcheck disable=SC1090 source=/home/hiroshi/Documents/jf/shared.sh
. "${JF_BASEDIR}/shared.sh"

function run_testcase() {
  local _file_to_be_searched="${1}"
  local _path="${2}"
  local _expected_return_code="${3}"
  local _expected_output="${4:-""}"
  local _actual_output
  local _actual_return_code=0
  local _msg=""
  local _ret=1
  _path=$(eval "echo ${_path}")
  _expected_output=$(eval "echo ${_expected_output}")
  _actual_output=$(search_file_in "${_file_to_be_searched}" "${_path}" 2> /dev/null) || {
    _actual_return_code=$?
  }
  if [[ ${_actual_return_code} -ne ${_expected_return_code} ]]; then
    _msg="Expected return code was ${_expected_return_code} but ${_actual_return_code} was returned"
  fi
  if [[ "${_actual_output}" != *"${_expected_output}"* ]]; then
    _msg="${_msg}\n'${_expected_output}' was expected to be found in output but not:\nActual output was:'${_actual_output}'"
  fi
  if [[ -z "${_msg}" ]]; then
    _ret=0
  fi
  printf "${_msg}"
  return ${_ret}
}

run_testcase "$@"
