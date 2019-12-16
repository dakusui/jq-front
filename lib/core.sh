[[ "${_SHARED_SH:-""}" == "yes" ]] && return 0
_SHARED_SH=yes

# shellcheck disable=SC1090
# source = lib/logging.sh
source "${JF_BASEDIR}/lib/logging.sh"

function is_effectively_empty_array() {
  [[ "${#}" == 0 ]] && return 0
  [[ "${#}" == 1 && "${1}" == "" ]] && return 0
  return 1
}

function hashcode() {
  local _nodeentry="${1}"
  echo -n "${_nodeentry}" | md5sum | cut -f 1 -d ' '
}

function join_by() {
  local IFS="$1"
  shift
  echo "$*"
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

function search_file_in() {
  local _target="${1}" _path="${2}" _path_base="${3:-${_JF_PATH_BASE}}"
  local i
  debug "begin: _target='${_target}', _path='${_path}', _path_base='${_path_base}'"
  IFS=':' read -r -a _arr <<<":${_path}"
  for i in "${_arr[@]}"; do
    local _ret
    _ret="$(echo "${i}/${_target}" | sed -E 's!/+!/!g')"
    if [[ -e "${_ret}" ]]; then
      debug "${_target} was found as '${_ret}' under '${i}'"
      echo "${_ret}"
      debug "end: _ret='${_ret}'"
      return 0
    fi
  done
  abort "File '${_target}' was not found in '${_path}'(cwd:'$(pwd)')"
}
