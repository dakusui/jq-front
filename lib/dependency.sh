#!/usr/bin/env bash
set -eu
[[ "${_DEPENDENCY_SH:-""}" == "yes" ]] && return 0
_DEPENDENCY_SH=yes

function _encode_filename() {
  local _filename="${1}" _dependency_space="${2}"
  local _ret
  _ret="${_JF_SESSION_DIR}/${_dependency_space}-$(hashcode "${_filename}").txt"
  echo "${_ret}"
}

function _mark_as_in_progress() {
  local _filename="${1}" _dependency_space="${2}"
  local _encoded_filename
  _encoded_filename="$(_encode_filename "${_filename}" "${_dependency_space}")"
  touch "${_encoded_filename}"
}

function _unmark_as_in_progress() {
  local _filename="${1}" _dependency_space="${2}"
  local _encoded_filename
  debug "check: unmark: '${_filename}'"
  _encoded_filename="$(_encode_filename "${_filename}" "${_dependency_space}")"
  rm "${_encoded_filename}" || {
    message "WARN: ${_filename} was not found."
  }
}

function _is_in_progress() {
  local _filename="${1}" _dependency_space="${2}"
  local _encoded_filename
  _encoded_filename="$(_encode_filename "${_filename}" "${_dependency_space}")"
  if [[ -e "${_encoded_filename}" ]]; then
    debug "'${_filename}'(${_encoded_filename}) is in progress"
    return 0
  fi
  debug "'${_filename}'(${_encoded_filename}) is NOT in progress"
  return 1
}

function _check_cyclic_dependency() {
  local _in="${1}" _dependency_space="${2}"
  if _is_in_progress "${_in}" inheritance; then
    abort "Cyclic ${_dependency_space} was detected on:'${_in}'"
  else
    debug "check: mark as in progress: '${_in}'"
    _mark_as_in_progress "${_in}" inheritance
  fi
}
