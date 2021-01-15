

function safe_path() {
  local _path="${1}"
  local _i _path_components _ret
  if [[ "${_path}" != "."* ]]; then
    abort "Invalid path '${_path}' was given. A JSON path should start with a dot ('.')"
  fi
  _path="${_path#.}"
  mapfile -td '.' _path_components < <(echo -n "${_path}")
  _ret=""
  for _i in "${_path_components[@]}"; do
    _ret="${_ret}"'."'${_i}'"'
  done
  echo -n "${_ret}"
}

safe_path "${1}"