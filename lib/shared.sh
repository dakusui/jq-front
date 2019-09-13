#!/usr/bin/env bash
set -eu

function mktemp_with_content() {
  local _content="${1:?No content was given}"
  local _ret
  # shellcheck disable=SC2154
  if [[ -z ${_content+x} ]]; then
    quit "Content was not set"
  fi
  _ret="$(mktemp)"
  echo "${_content}" >"${_ret}"
  echo "${_ret}"
}

function mktempdir() {
  mktemp -d
}

function debug() {
  if [[ ${_JF_DEBUG:-""} == "enabled" ]]; then
    message "DEBUG" "$@"
  fi
}

function message() {
  local IFS=" "
  local _o
  _o="${1}"
  shift
  echo -e "${_o}" "$*" >&2
}

####
# Used when a condition is not met and a program SHOULD NOT go on.
function quit() {
  message "ERROR" "${@}"
  local _i=0
  local _e
  while _e="$(caller $_i)"; do
    message "  at ${_e}"
    _i=$((_i + 1))
  done
  return 1
}

function abort() {
  quit "${@}" || exit 1
}

function all_paths() {
  local _json="${1}"
  echo "${_json}" | jq -r -c 'path(..)|map(if type=="number" then "["+tostring+"]" else "\""+tostring+"\"" end)|join(".")|gsub("\\.\\[";"[")|"."+tostring'
}

function is_object() {
  local _json_content="${1}"
  echo "${_json_content}" | jq '.|if type=="object" then true else false end'
}

function has_value_at() {
  local _path="${1}"
  local _json="${2}"
  local _val
  _val=$(echo "${_json}" | jq "${_path}|select(.)")
  if [[ -z ${_val} ]]; then
    echo false
  else
    echo true
  fi
}

function value_at() {
  local _path="${1}" # A path from which the output is retrieved.
  local _json="${2}" # JSON content
  if [[ $(has_value_at "${_path}" "${_json}") == true ]]; then
    echo "${_json}" | jq -r -c "${_path}" || quit "Failed to access '${_path}'."
  else
    if [ -z ${3+x} ]; then
      quit "Failed to access '${_path}' and default value for it was not given."
    else
      echo "${3}"
    fi
  fi
}

function keys_of() {
  local _path="${1}" # A path from which the output is retrieved.
  local _json="${2}" # JSON content
  echo "${_json}" | jq -r -c "${_path} | keys[]" || quit "Failed to access keys of '${_path}' in '${_json}'"
}

function search_file_in() {
  local _target="${1}"
  local _path="${2}"
  if [[ "${_target}" == "${_JF_PATH_BASE}/"* ]]; then
    echo "${_target}"
    return 0
  fi
  IFS=':' read -r -a _arr <<<"${_path}"
  for i in "${_arr[@]}"; do
    local _ret="${i}/${_target}"
    if [[ -e "${_ret}" ]]; then
      echo "${_ret}"
      return 0
    fi
  done
  quit "File '${_target}' was not found in '${_path}'"
}
