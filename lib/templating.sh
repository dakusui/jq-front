####
#
# Function intended to be used on templating
#
function ref() {
  local _path="${1}"
  value_at "${_path}" "$(cat "$(self)")"
}

####
#
# Function intended to be used on templating
#
function self() {
  ####
  # This variable is assigned by a function that executes "eval" for templating.
  # That is, run_jf() in the main script file.
  # shellcheck disable=SC2154
  echo "${_out}"
}
