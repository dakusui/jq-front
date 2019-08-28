#!/bin/bash -eu

# shellcheck disable=SC1090
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
export POWERJSON_PATH=".:./powerjson/builtin"

function _remove_meta_nodes() {
  local _target="${1}"
  local _cur
  _cur="$(mktemp)"
  cp "${_target}" "${_cur}"
  for i in $(all_paths "$(cat "${_target}")" | grep '"$extends"$'); do
    local _next
    _next="$(mktemp)"
    jq ".|del(${i})" "${_cur}" >"${_next}"
    _cur="${_next}"
  done
  jq '.|del(."$private")' "${_cur}"
}

function _merge_object_nodes() {
  local _a="${1}"
  local _b="${2}"
  jq -s '.[0] * .[1]' "${_a}" "${_b}"
}

function _expand_internal_inheritances() {
  local _target="${1}"
  local _private_nodes_dir="${2}"
  local _cur
  _cur="$(mktemp)"
  echo '{}' >"${_cur}"
  for i in $(all_paths "$(cat "$(search_file_in "${_target}" "${_private_nodes_dir}")")" | grep '"$extends"$'); do
    local _next
    _next="$(mktemp)"
    for j in $(jq -r -c "${i}[]" "${_target}"); do
      jq -n "input | ${i%.\"\$extends\"}=input" "${_cur}" "${j}" >"${_next}"
      _cur="${_next}"
    done
  done
  jq -r -c . "${_cur}"
}

####
# Used when a condition is not met and a program should NOT go on.
function abort() {
  local _message="${1}"
  message "ERROR:${_message}"
  local _i=0
  local _e
  while _e="$(caller $_i)"; do
    message "  at ${_e}"
    _i=$((_i + 1))
  done
  return 1
}

function message() {
  local _message="${1}"
  echo "${_message}" >&2
}

function all_paths() {
  local _json="${1}"
  echo "${_json}" | jq -r -c 'path(..)|[.[]]|map(if type=="number" then "["+tostring+"]" else "\""+tostring+"\"" end)|join(".")|gsub("\\.\\[";"[")|"."+tostring'
}

function has_value_at() {
  local _path="${1}"
  local _json="${2}"
  local _val
  _val=$(echo "${_json}" | jq "${_path}|select(.)")
  if [[ -z ${_val} ]]; then
    echo "F"
  else
    echo "T"
  fi
}

function value_at() {
  local _path="${1}" # A path from which the output is retrieved.
  local _json="${2}" # JSON content
  if [[ $(has_value_at "${_path}" "${_json}") == 'T' ]]; then
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
  if [[ "${_target}" == /* ]]; then
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

function expand_external_inheritances() {
  local _target="${1}"
  local _path="${2}"
  debug "begin:expand_external_inheritances"
  ####
  # This is intentionally using single quotes to pass quoted path expression to jq.
  # shellcheck disable=SC2016
  local _parents
  local _cur
  _cur="$(mktemp)"
  cat "${_target}" >"${_cur}"
  # shellcheck disable=SC2016
  # this is intentionally suppressing expansion to pass the value to jq.
  if [[ $(has_value_at '."$extends"' "$(cat "${_target}")") == 'T' ]]; then
    _parents=$(value_at '."$extends"[]' "$(cat "${_target}")")
    local i
    for i in $_parents; do
      local _next
      local _tmp
      _next=$(mktemp)
      _tmp=$(mktemp)
      expand_external_inheritances "$i" "${_path}" >"${_tmp}"
      _merge_object_nodes "${_tmp}" "${_cur}" >"${_next}"
      _cur="${_next}"
    done
  fi
  jq -r -c '.|del(.["$extends"])' "$(search_file_in "${_cur}" "${_path}")"
  debug "end:expand_external_inheritances"
}

function materialize_private_nodes() {
  local _target="${1}"
  local _content
  local _ret
  debug "begin:materialize_private_nodes"
  _content="$(cat "${_target}")"
  _ret="$(mktemp -d)"
  # shellcheck disable=SC2016
  for i in $(keys_of '."$private"' "${_content}"); do
    echo "${_content}" | jq '."$private".'"${i}" >"${i}"
  done
  echo "${_ret}"
  debug "end:materialize_private_nodes"
}

function expand_internal_inheritances() {
  local _target="${1}"
  local _private_nodes_dir="${2}"
  local _expanded
  local _clean
  debug "begin:expand_internal_inheritances"
  _expanded="$(mktemp)"
  _clean="$(mktemp)"

  _expand_internal_inheritances "${_target}" "${_private_nodes_dir}" >"${_expanded}"
  _remove_meta_nodes "${_target}" >"${_clean}"
  _merge_object_nodes "${_expanded}" "${_clean}"
  debug "end:expand_internal_inheritances"
}

function perform_templating() {
  debug "begin:perform_templating"
  local _src_file="${1}"
  local _content
  local _ret
  _content=$(cat "${_src_file}" | sed -r 's/\"/\\\"/g')
  _ret=$(eval "echo \"${_content}\"")
  echo "${_ret}"
  debug "end:perform_templating"
}

function ref() {
  local _path="${1}"
  value_at "${_path}" "$(cat "$(self)")"
}

function self() {
  echo "${_out}"
}

function powerjson() {
  local _target="${1}"
  local _templating="${2}"
  local _tmp
  local _private_nodes_dir
  local _out
  _tmp="$(mktemp)"
  expand_external_inheritances "${_target}" "${POWERJSON_PATH}" >"${_tmp}"
  _private_nodes_dir=$(materialize_private_nodes "${_tmp}")
  _out=$(mktemp)
  expand_internal_inheritances "${_tmp}" "${_private_nodes_dir}:${POWERJSON_PATH}" >"${_out}"
  if [[ "${_templating}" == "yes" ]]; then
    perform_templating "${_out}"
  else
    cat "${_out}"
  fi
}

function usage_exit() {
  abort "Usage: $0 [-h|--help] [] TARGET"
}

function parse_opt() {
  # Call getopt to validate the provided input.
  options=$(getopt -o he --long help --long enable-_templating -- "$@") || {
    usage_exit
  }

  eval set -- "$options"
  while true; do
    case "$1" in
    -h | --help)
      usage_exit
      ;;
    --)
      shift
      break
      ;;
    esac
    shift
  done
  echo "${@}"
  if [[ $# == 0 ]]; then
    usage_exit
  fi
}

powerjson "${1}" "yes"
# perform_templating "A.json"
