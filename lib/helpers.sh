[[ "${_HELPERS_SH:-""}" == "yes" ]] && return 0
_HELPERS_SH=yes

function _debug_abort() {
  print_stacktrace "DEBUG: error trapped"
  exit 1
}

function _mangle_path() {
  local _path="${1}" _path_base="${2}"
  local _ret=""
  if [[ -z "${_path_base}" ]]; then
    echo "${_path}"
    return 0
  fi
  IFS=":" read -r -a _arr <<<"${_path}"
  for i in "${_arr[@]}"; do
    local _cur="${_path_base}"
    if [[ ${i} == .* ]]; then
      # _JF_CWD always starts with '/' since it is an absolute path to current working directory by definition.
      _cur="${_cur}${i/./${_JF_CWD}}"
    else
      _cur="${_cur}${i}"
    fi
    if [[ "${_ret}" == "" ]]; then
      _ret="${_cur}"
    else
      _ret="${_ret}:${_cur}"
    fi
  done
  echo "${_path_base}:${_ret}"
}
