#!/usr/bin/env bash
set -eu
[[ "${_NODEPOOL_SH:-""}" == "yes" ]] && return 0
_NODEPOOL_SH=yes

# shellcheck disable=SC1090
# source = lib/nodepool.sh
source "${JF_BASEDIR}/lib/nodepool.sh"

function nodepool_prepare() {
  local _driver_funcname="${1}"
  local _pooldir
  _pooldir="$(mktemp -d --suffix=jq-front-nodepool)"
  _define_nodeentry_reader "${_driver_funcname}" "${_pooldir}"
  echo "${_pooldir}"
}

function nodepool_read_nodeentry() {
  local _nodeentry="${1}" _path="${2}" _pooldir="${3}" _validation_mode="${4:-no}"
  local _cache
  _cache="${_pooldir}/$(hashcode "${_nodeentry}")"
  perf "begin: '${_nodeentry}' (cached:'${_cache}')"
  [[ -e "${_cache}" ]] || {
    perf "Cache miss for node entry: '${_nodeentry}'"
    _read_nodeentry "${_nodeentry}" "${_validation_mode}" "${_path}" >"${_cache}"
  }
  cat "${_cache}"
  perf "end: '${_nodeentry}' (cached:'${_cache}')"
}

function _define_nodeentry_reader() {
  local _driver_funcname="${1}" _pooldir="${2}"
  function read_nodeentry() {
    local _nodeentry="${1}" _validation_mode="${2}" "${_path}"="${3}"
    "${_driver_funcname}" "${_nodeentry}" "${_validation_mode}" "${_path}"
  }
}

function _locate_file() {
  local _file="${1}" _path="${2}"
  _search_file_in "${_file}" "${_path}"
}

function _nodepool_expand_inheritances() {
  local _nodeentry="${1}"
  local _validation_mode="${2}"
  local _path="${3}"
  local _content _out _absfile _processor _args _ret
  local -a _specifier

  mapfile -t -d ';' _specifier <<<"${_nodeentry};;"
  _absfile="$(_locate_file "${_specifier[0]}" "${_path}")"
  _processor="${_specifier[1]}"
  _args="${_specifier[2]}"

  perf "begin: ${_nodeentry}"
  _absfile="$(find_file_in_path "${_absfile}" "${_path}")"
  # Fail on command substitution cannot be checked directly
  # shellcheck disable=SC2181
  [[ $? == 0 ]] || abort "Failed to find a file '${_absfile}'."
  # Update _path to be able to find a file placed in the same directory as _absfile's
  _path="$(dirof "${_absfile}"):${_path}"
  _content="$(cat "${_absfile}")"
  _content="$(jsonize "${_absfile}" "${_processor}" "${_args}")"
  if ! is_json "${_content}"; then
    abort "Malformed JSON was given:'${_nodeentry}'='${_content}'"
  fi
  if is_object "${_content}"; then
    local _tmp _private_nodes_dir _c _expanded
    ####
    # Strangely the line below does not causes a quit on a failure.
    # Explitly check and abotrt this functino.
    _c="$(expand_filelevel_inheritances "${_absfile}" "${_validation_mode}" "${_path}")" ||
      abort "File-level expansion failed for '${_absfile}'"
    _tmp="$(mktemp_with_content "${_c}")"
    _private_nodes_dir=$(materialize_private_nodes "${_tmp}")
    expand_inheritances_of_private_nodes "${_private_nodes_dir}" \
      "enabled" \
      "${_private_nodes_dir}:${_path}"
    _expanded="$(expand_nodelevel_inheritances "${_tmp}" "${_validation_mode}" "${_private_nodes_dir}:${_path}")" ||
      abort "Failed to expand node level inheritance for file:'${_nodeentry}'(3)"
    _out=$(mktemp_with_content "${_expanded}")
  else
    : # Clear $?
    _out="$(mktemp_with_content "${_content}")"
  fi
  cat "${_out}"
  perf "end: ${_nodeentry}"
  #----------------------
}

function jsonize() {
  local _absfile="${1}" _processor="${2:-""}" _args="${3:-""}"
  local _ret
  debug "in: '${_absfile}' '${_processor}' '${_args}'"
  if [[ ${_processor} == "" ]]; then
    local _cmd="jq"
    if [[ "${_absfile}" == *.yaml || "${_absfile}" == *.yml ]]; then
      _cmd="yq"
    fi
    # Let the args split. Since it's args.
    # shellcheck disable=SC2086
    _ret="$(${_cmd} . ${_args} "${_absfile}")"
  else
    if [[ "${_processor}" == SOURCE ]]; then
      # Only number of files matters and it's safe to use ls here.
      # shellcheck disable=SC2012
      cp "${_absfile}" "$(_sourced_files_dir)/$(ls "$(_sourced_files_dir)" | wc -l)"
      _ret="{}"
    else
      export _path
      _ret="$("${_processor}" "${_absfile}" ${_args} | jq .)"
      unset _path
    fi
  fi
  debug "output: '${_ret}'"
  echo "${_ret}"
}
