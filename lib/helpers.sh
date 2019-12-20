[[ "${_HELPERS_SH:-""}" == "yes" ]] && return 0
_HELPERS_SH=yes

function _debug_abort() {
  print_stacktrace "DEBUG: error trapped"
  exit 1
}

