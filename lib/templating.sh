set -eu
[[ "${_TEMPLATING_SH:-""}" == "yes" ]] && return 0
_TEMPLATING_SH=yes

function perform_templating() {
  local _src_file="${1}" _levels="${2}"
  local _content _ret
  perf "begin"
  # define builtin functions such as "ref", "self"
  _define_builtin_functions
  # source files, for which SOURCE directive is specified
  _source_files
  _perform_templating "$(cat "${_src_file}")" "${_levels}"
  perf "end"
}

function _perform_templating() {
  local _content="${1}" _levels="${2}"
  local _ret="${_content}"
  local _c="${_levels}"
  local -a _keys
  # Shorter path comes earlier than longer.
  while [[ "${_c}" -ge 0 || "${_levels}" == -1 ]]; do
    mapfile -t _keys < <(_paths_of_string_nodes_perform_templating "${_ret}")
    if is_empty_array "${_keys[@]}"; then
      break
    fi
    if [[ "${_c}" -eq 0 ]]; then
      error "Templating has been repeated ${_levels} time(s) but it did not finish.: Keys left untemplated are: [${_keys[*]}]"
    fi
    debug "begin loop"
    for i in "${_keys[@]}"; do
      local _node_value _templated_node_value _ret_file
      _node_value="$(value_at "${i}" "${_ret}")"
      _ret_file=$(mktemp_with_content "${_ret}")
      _templated_node_value="$(_render_text_node "${_node_value}" "${i}" "${_ret_file}")"
      _ret="$(jq -r -c -n "input|${i}=input" <(echo "${_ret}") <(echo "${_templated_node_value}"))"
    done
    _c=$((_c - 1))
    debug "end loop"
  done
  echo "${_ret}"
}

function _paths_of_string_nodes_perform_templating() {
  local _content="${1}"
  echo "${_content}" | jq -r -c -L "${JF_BASEDIR}/lib" '#---
import "shared" as shared;

[paths(scalars_or_empty
      |select(type=="string" and (startswith("eval:") or
                                  startswith("template:"))))]
              |sort
              |sort_by(length)
              |.[]
              |shared::path2pexp(.)'
}

function _render_text_node() {
  local _node_value="${1}"
  local _path="${2}" # DO NOT REMOVE: This local variable is referenced by built-in functions invoked on 'templating' stage.
  local _self="${3}" # DO NOT REMOVE: This local variable is referenced by built-in functions invoked on 'templating' stage.
  local _mode="raw" _quote="yes" _ret_code=0  _expected_type="string"
  local _body _ret
  if [[ "${_node_value}" != template:* && "${_node_value}" != eval:* && "${_node_value}" != raw:* ]]; then
    abort "Non-templating text node was found: '${_node_value}'"
  fi
  _mode="${_node_value%%:*}"
  _body="${_node_value#*:}"
  if [[ "${_body}" == object:* || "${_body}" == array:* || "${_body}" == string:* || "${_body}" == number:* || "${_body}" == boolean:* ]] \
    ; then
    if [[ "${_body}" != string:* ]]; then
      _quote="no"
    fi
    _expected_type="${_body%%:*}"
    _body="${_body#*:}"
  fi

  if [[ "${_mode}" == "template" || "${_mode}" == "eval" ]]; then
    local _error_prefix="ERROR: "
    local _error _error_out
    export _path
    _error="$(mktemp)"
    # Perform the 'templating'
    _ret="$(eval "echo \"${_body}\"" 2>"${_error}")"
    unset _path
    # shellcheck disable=SC2002
    _error_out="$(cat "${_error}")"
    [[ "${_error_out}" != *"${_error_prefix}"* ]] || abort "Error was detected during templating: $(cat "${_error}")"
    debug "stderr during eval:'${_error_out}'"
  elif [[ "${_mode}" == "raw" ]]; then
    _ret="${_body}"
  fi
  if [[ "${_quote}" == yes ]]; then
    _ret="${_ret//\\/\\\\}"
    _ret="\"${_ret//\"/\\\"}\""
  else
    _ret="${_ret}"
  fi
  local _actual_type="(malformed)"
  _actual_type="$(echo "${_ret}" | jq -r '.|type')"
  debug "expected type:'${_expected_type}' actual type:'${_actual_type}'"
  [[ "${_expected_type}" == "${_actual_type}" ]] ||
    abort "Type mismatch was detected for:'${_node_value}' expected type:'${_expected_type}' actual type:'${_actual_type}'"
  echo "${_ret}"
  return "${_ret_code}"
}

####
#
# Function intended to be used on 'script inheritance'.
# Search for a file from an environment variable "_JF_PATH" and prints an absolute path of it if found.
# In case it is not found, 1 will be returned.
#
# This function is indirectly called by 'jsonize' function through a command line it constructs
#
function find_file() {
  local _target="${1}"
  search_file_in "${_target}" "${_path}"
}

function _source_files() {
  local _i _files
  # We know that there is no alphanumerically named files under $(_source_files_dir)
  # shellcheck disable=SC2012
  mapfile -t _files <<<"$(ls "$(_sourced_files_dir)" | sort -n)"
  for _i in "${_files[@]}"; do
    [[ "${_i}" == "" ]] && break
    # shellcheck disable=SC1090
    source "$(_sourced_files_dir)/${_i}"
  done
}

function _define_builtin_functions() {
  ####
  #
  # This is a function intended to be used on templating (_render_text_node)
  function ref() {
    # shellcheck disable=SC2181
    [[ $? == 0 ]] || abort "${_error_prefix}Failure was detected."
    local _path="${1}"
    local value type
    value=$(value_at "${_path}" "$(cat "$(self)")")
    type="$(type_of "${value}")"
    debug "value:'${value}'(type:'${type}') self:'${_self}' path:'${_path}'"
    if [[ "${type}" == string && ("${value}" == eval:* || "${value}" == template:*) ]]; then
      local ret
      _check_cyclic_dependency "${_path}" reference
      ret="$(_render_text_node "${value}" "${_path}" "${_self}")"
      [[ $? == 0 ]] || abort "TODO"
      _unmark_as_in_progress "${_path}" reference
      jq -r -c '.' <(echo "${ret}")
    else
      echo "${value}"
    fi
  }

  ####
  # Prints the entire file (before templating).
  #
  # This is a function intended to be used on templating (_render_text_node)
  function self() {
    # shellcheck disable=SC2181
    [[ $? == 0 ]] || abort "${_error_prefix}Failure was detected."
    echo "${_self}"
  }
  ####
  # A function that prints a node path to the text node, where the calls this function is directly made.
  function curn() {
    # shellcheck disable=SC2181
    [[ $? == 0 ]] || abort "${_error_prefix}Failure was detected."
    debug "cur:_path='${_path}'"
    echo "${_path}"
  }

  ####
  # A function that prints a node path to a container element, which is an array or an object, that encloses the entry
  # belongs to.
  # An entry here means a pair of key and value or an element in an array.
  function cur() {
    parent "$(curn)"
  }

  ####
  # Prints a path to a parent node of a given path.
  # Note that single level path results in an empty string.
  # That is ```parent .node``` will print nothing.
  # This is intentional to be able to do ```$(ref $(parent $(cur)).uncle)``` even if ```$(cur)``` is either
  # ```.node``` or ```.node.child```
  function parent() {
    # shellcheck disable=SC2181
    [[ $? == 0 ]] || abort "${_error_prefix}Failure was detected."
    local _path="${1}"
    local _level="${2:-1}"
    if [[ ! "${_path}" == .* ]]; then
      abort "Path was not valid:(${_path}), it must start with a '.'"
    fi
    if [[ "${_path}" == "." ]]; then
      abort "Root does not have a parent.:(${_path})"
    fi
    jq -r -c -n -L "${JF_BASEDIR}/lib" \
      'import "shared" as shared;
      .|path('"${_path}"')|.[0:-'"${_level}"']|shared::path2pexp(.)'
  }

  function error() {
    abort "${@}"
  }
}
