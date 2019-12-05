function nodepool_prepare() {
  mktemp -d --suffix=jq-front-nodepool
}

function nodepool_readnode() {
  local _handler_funcname="${1}" _pooldir="${2}" _path="${3}" _nodeentry="${4}" _validation_mode="${5}"
  local -a _specifier
  local _absfile _processor _args _ret
  # shellcheck disable=SC2116
  mapfile -t -d ';' _specifier <<<"$(echo "${_nodeentry};;")"
  _absfile="$(_locate_file "${_specifier[0]}" "${_path}")"
  _processor="${_specifier[1]}"
  _args="${_specifier[2]}"
  _ret="$(_readnode "${_handler_funcname}" "${_validation_mode}" "${_pooldir}" "${_absfile}" "${_processor}" "${_args}")"
  echo "${_ret}"
}

function _jsonize() {
  local _absfile="${1}" _processor="${2:-""}" _args="${3:-""}"
  local _ret
  if [[ ${_processor} == "" ]]; then
    local _cmd="jq"
    if [[ "${_absfile}" == *.yaml || "${_absfile}" == *.yml ]]; then
      _cmd="yq"
    fi
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
  echo "${_ret}"
}

function _locate_file() {
  local _file="${1}" _path="${2}"
  local _ret
  echo "${_ret}"
}

function _readnode() {
  local _handler_funcname="${1}" _validation_mode="${2}" _absfile="${4}"
  _ret="$(_jsonize "${_absfile}" "${_processor}" "${_args}")"
  _validate_json "${_ret}" "${_validation_mode}"
  "${_handler_funcname}" "${_absfile}" "${_validation_mode}" "${_path}"
}

function _validate_json() {
  local _in="${1}" _mode="${2}"
  local _out=
  {
    _out=$(ajv validate -s "${_JF_SCHEMA_DIR}/${_mode}.json" -d "${_in}" 2>&1)
  } || {
    abort "Validation by ajv for '${_in}' was failed:\n${_out}"
  }
}

function _sourced_files_dir() {
  echo "${_JF_SESSION_DIR}/source_files"
}

function _validate_jf_json_with() {
  _validate_json "${1}" "${2}"
}
