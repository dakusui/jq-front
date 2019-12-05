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
