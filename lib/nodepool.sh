function nodepool_prepare() {
  mktemp -d --suffix=jq-front-nodepool
}

function nodepool_readnode() {
  local _pooldir="${1}" _path="${2}" _nodeentry="${3}" _validation_mode="${4}"
  local -a _specifier
  local _absfile _processor _args _ret
  # shellcheck disable=SC2116
  mapfile -t -d ';' _specifier <<<"$(echo "${_nodeentry};;")"
  _absfile="$(_locate_file "${_specifier[0]}" "${_path}")"
  _processor="${_specifier[1]}"
  _args="${_specifier[2]}"
  _ret="$(_readnode "${_pooldir}" "${_absfile}" "${_processor}" "${_args}")"
  _validate_json "${_ret}" "${_validation_mode}"
  echo "${_ret}"
}

function _jsonize() {
  local _absfile="${1}" _processor="${2:-""}" _args="${3:-""}"
  local _ret
  echo "${_ret}"
}

function _locate_file() {
  local _file="${1}" _path="${2}"
  local _ret
  echo "${_ret}"
}

function _readnode() {
  local _pooldir="${1}" _absfile="${2}" _processor="${3:-""}" _args="${4:-""}"
  local _ret
  echo "${_ret}"
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

function _validate_jf_json_with() {
  _validate_json "${1}" "${2}"
}
