#!/usr/bin/env bash
set -eu

function mktemp_with_content() {
  local _content="${1:?No content was given}"
  local _ret
  _ret="$(mktemp)"
  echo "${_content}" >"${_ret}"
  echo "${_ret}"
}

function mktempdir() {
  mktemp -d
}

function is_debug_enabled() {
  [[ ${_JF_DEBUG:-""} == "enabled" ]] && return 0
  return 1
}

function debug() {
  if is_debug_enabled; then
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

function abort() {
  print_stacktrace "ERROR:" "${@}"
  exit 1
}

function print_stacktrace() {
  local _message="${1}"
  shift
  message "${_message}" "${@}"
  local _i=0
  local _e
  while _e="$(caller $_i)"; do
    message "  at ${_e}"
    _i=$((_i + 1))
  done
}

function all_paths() {
  local _json="${1}"
  jq -e . >/dev/null 2>&1 <<<"${_json}" || abort "Malformed JSON string was given.: '${_json}'"
  echo "${_json}" | jq -r -c '#---
              def path2pexp(v):
                reduce .[] as $segment (""; . + ($segment | if type == "string" then ".\"" + . + "\"" else "[\(.)]" end));

              [paths(..)]
                |sort
                |sort_by(length)
                |.[]
                |path2pexp(.)'
}

function is_json() {
  local _content="${1}"
  local _exitcode
  jq 'empty' <(echo "${_content}") >/dev/null 2>&1
  _exitcode=$?
  return $_exitcode
}

function is_object() {
  local _json_content="${1}"
  local _ret
  _ret="$(echo "${_json_content}" | jq '.|if type=="object" then 0 else 1 end' 2>/dev/null)"
  return "${_ret}"
}

function type_of() {
  local _json_content="${1}"
  jq -r -c '.|type' <(echo "${_json_content}") || echo "string"
}

function has_value_at() {
  local _path="${1}"
  local _json="${2}"
  local _val
  _val=$(echo "${_json}" | jq "${_path}|select(.)") || return 1
  if [[ -z ${_val} ]]; then
    return 1
  else
    return 0
  fi
}

function value_at() {
  local _path="${1}" # A path from which the output is retrieved.
  local _json="${2}" # JSON content
  if has_value_at "${_path}" "${_json}"; then
    echo "${_json}" | jq -r -c "${_path}" || abort "Failed to access '${_path}'."
  else
    if [ -z ${3+x} ]; then
      abort "Failed to access '${_path}' and default value for it was not given."
    else
      echo "${3}"
    fi
  fi
}

function keys_of() {
  local _path="${1}" # A path from which the output is retrieved.
  local _json="${2}" # JSON content
  echo "${_json}" | jq -r -c "${_path} | keys[]" || abort "Failed to access keys of '${_path}' in '${_json}'"
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
  abort "File '${_target}' was not found in '${_path}'"
}
