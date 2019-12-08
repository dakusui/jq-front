#!/usr/bin/env bash
set -eu
[[ "${_SHARED_SH:-""}" == "yes" ]] && return 0
_SHARED_SH=yes

function hashcode() {
  local _nodeentry="${1}"
  echo -n "${_nodeentry}" | md5sum | cut -f 1 -d ' '
}

function mktemp_with_content() {
  ####
  # This is a logic to check preceding procedure was successful.
  # shellcheck disable=SC2181
  [[ $? == 0 ]] || abort "Preceding command is suspected to be failed already."
  local _content="${1:?No content was given}"
  local _ret
  _ret="$(mktemp)"
  echo "${_content}" >"${_ret}"
  echo "${_ret}"
}

function join_by() {
  local IFS="$1"
  shift
  echo "$*"
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
    message "DEBUG: $(date '+%Y-%m-%d %H:%M:%S.%3N'): ${FUNCNAME[1]}:" "${@}"
  fi
}

function is_perf_enabled() {
  [[ ${_JF_PERF:-""} == "enabled" ]] && return 0
  return 1
}

function perf() {
  if is_perf_enabled; then
    message "PERF: $(date '+%Y-%m-%d %H:%M:%S.%3N'): ${FUNCNAME[1]}:" "${@}"
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

function _validate_json() {
  local _in="${1}" _schema_file="${2}"
  local _out=
  {
    _out=$(ajv validate -s "${_schema_file}" -d "${_in}" 2>&1)
  } || {
    abort "Validation by ajv for '${_in}' was failed:\n${_out}"
  }
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
    local _ret="${_target}"
    [[ "${_JF_PATH_BASE}" != "" ]] && _ret="${_JF_PATH_BASE}/${_target}"
    debug "${_target} was found as '${_ret}' under JF_PATH_BASE: '${_JF_PATH_BASE}'"
    echo "${_ret}"
    return 0
  fi
  IFS=':' read -r -a _arr <<<"${_path}"
  for i in "${_arr[@]}"; do
    local _ret="${i}/${_target}"
    if [[ -e "${_ret}" ]]; then
      debug "${_target} was found as '${_ret}' under '${i}'"
      echo "${_ret}"
      return 0
    fi
  done
  abort "File '${_target}' was not found in '${_path}'(cwd:'$(pwd)')"
}
