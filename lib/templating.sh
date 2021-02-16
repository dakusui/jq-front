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
  local _ret="${_content}" _c="${_levels}"
  local -a _entries
  # Shorter path comes earlier than longer.
  debug "begin"
  while [[ "${_c}" -ge 0 || "${_levels}" == -1 ]]; do
    local _each
    mapfile -t _entries < <(_string_node_entries_to_perform_templating "${_ret}")
    # shellcheck disable=SC2015
    is_effectively_empty_array "${_entries[@]}" && break || :
    if [[ "${_c}" -eq 0 ]]; then
      error "Templating has been repeated ${_levels} time(s) but it did not finish.: Entries left untemplated are: [${_entries[*]}]"
    fi
    perf "begin loop: remaining: ${_c}"
    for _each in "${_entries[@]}"; do
      local _node_path _node_value _templated_node_value _entry
      perf "processing: entry:'${_each}'"
      IFS=$'\t' read -r -a _entry <<<"${_each}"
      _node_path="${_entry[0]}"
      _node_value="${_entry[1]}"
      debug "processing: nodepath:'${_node_path}', nodevalue:'${_node_value}'"
      _templated_node_value="$(_render_text_node "${_node_value}" "${_node_path}" "${_ret}")"
      _ret="$(jq -r -c -n "input|${_node_path}=input" <(echo "${_ret}") <(echo "${_templated_node_value}"))"
    done
    perf "end loop: remaining: ${_c}"
    _c=$((_c - 1))
  done
  echo "${_ret}"
  debug "end"
}

function _string_node_entries_to_perform_templating() {
  local _content="${1}"
  echo "${_content}" | jq -r -c -L "${JF_BASEDIR}/lib" '#---
import "shared" as shared;
. as $content
|[paths(scalars_or_empty
       |select(type=="string" and (startswith("eval:") or
                                   startswith("template:"))))]
       |sort
       |sort_by(length)
       |.[]
       |. as $p
       |$content
       |[shared::path2pexp($p),getpath($p)]
       |@tsv'
}

function _render_text_node() {
  local _node_value="${1}"
  local _path="${2}"         # DO NOT REMOVE: This local variable is referenced by built-in functions invoked on 'templating' stage.
  local _self_content="${3}" # DO NOT REMOVE: This local variable is referenced by built-in functions invoked on 'templating' stage.
  local _mode="raw" _quote="yes" _ret_code=0 _expected_type="string" _body _ret
  if [[ "${_node_value}" != template:* && "${_node_value}" != eval:* && "${_node_value}" != raw:* ]]; then
    abort "Non-templating text node was found: '$(trim "${_node_value}")'"
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
    function _err_handler() {
      abort "Failed on eval: 'echo \"${_body}\"'"
    }
    local _error_prefix="ERROR: " _error _error_out _original_err_handler
    export _path
    _original_err_handler="$(trap -p ERR)"
    trap _err_handler ERR
    _error="$(mktemp "${TMPDIR:-/tmp}/templating-XXXXXXXXXX.stderr")"
    debug "error: '${_error}'"
    # Perform the 'templating'
    _ret="$(eval "echo ${_body}" 2>"${_error}")"
    [[ -z "${_original_err_handler}" ]] || ${_original_err_handler}
    unset _path
    # shellcheck disable=SC2002
    _error_out="$(cat "${_error}")"
    [[ "${_error_out}" != *"${_error_prefix}"* ]] || abort "$(printf "Error was detected during templating: '${_body}'\n====\n%s\n----" "$(cat "${_error}")")"
    debug "value: '${_ret}', stderr during eval:'${_error_out}'"
  elif [[ "${_mode}" == "raw" ]]; then
    _ret="${_body}"
  fi
  if [[ "${_quote}" == yes ]]; then
    _ret="${_ret//\\/\\\\}"
    _ret="\"${_ret//\"/\\\"}\""
  fi
  local _actual_type="(malformed)"
  _actual_type="$(echo "${_ret}" | jq -r '.|type')" ||
    abort "'$(trim "${_node_value}")' was rendered into '${_ret}' and it seems not a wel-formed JSON."
  debug "expected type:'${_expected_type}' actual type:'${_actual_type}'"
  [[ "${_expected_type}" == "${_actual_type}" ]] ||
    abort "Type mismatch was detected for:'$(trim "${_node_value}")' expected type:'${_expected_type}' actual type:'${_actual_type}'"
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
    [[ $? == 0 ]] || abort "Preceding failure was detected by '${FUNCNAME[0]}'."
    local _path="${1}"
    local value type
    info "args:'${*}'"
    message "_path:'${_path}'"
    value=$(value_at "$(safe_path "${_path}")" "$(self)")
    type="$(type_of "${value}")"
    debug "value:'${value}'(type:'${type}') path:'${_path}'"
    if [[ "${type}" == string && ("${value}" == eval:* || "${value}" == template:*) ]]; then
      local ret
      _check_cyclic_dependency "${_path}" reference
      ret="$(_render_text_node "${value}" "${_path}" "${_self_content}")" || abort "TODO"
      _unmark_as_in_progress "${_path}" reference
      jq -r -c '.' <(echo "${ret}")
    else
      echo "${value}"
    fi
  }

  function refexists() {
    # shellcheck disable=SC2181
    [[ $? == 0 ]] || abort "Preceding failure was detected by '${FUNCNAME[0]}'."
    local _path="${1}"
    info "args:'${*}'"
    has_value_at "$(safe_path "${_path}")" "$(self)"
  }

  function reftag() {
    # shellcheck disable=SC2181
    [[ $? == 0 ]] || abort "Preceding failure was detected by '${FUNCNAME[0]}'."
    local _tagname="${1}"
    local _curpath
    info "args:'${*}'"
    _curpath="$(curn)"
    while [[ "${_curpath}" != "" ]]; do
      _curpath="$(parent "${_curpath}")"
      if refexists "${_curpath}.${_tagname}"; then
        ref "${_curpath}.${_tagname}"
        return 0
      fi
    done
    abort "The specified tag:'${_tagname}' was not found from the current path:'$(curn)'"
  }

  ####
  # Prints the entire file (before templating).
  #
  # This is a function intended to be used on templating (_render_text_node)
  function self() {
    # shellcheck disable=SC2181
    [[ $? == 0 ]] || abort "Preceding failure was detected by '${FUNCNAME[0]}'."
    info "args:(none)"
    echo "${_self_content}"
  }
  ####
  # A function that prints a node path to the text node, where the calls this function is directly made.
  function curn() {
    # shellcheck disable=SC2181
    [[ $? == 0 ]] || abort "Preceding failure was detected by '${FUNCNAME[0]}'."
    info "args:(none)"
    debug "cur:_path='${_path}'"
    echo "${_path}"
  }

  ####
  # A function that prints a node path to a container element, which is an array or an object, that encloses the entry
  # belongs to.
  # An entry here means a pair of key and value or an element in an array.
  function cur() {
    info "args:'${*}'"
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
    [[ $? == 0 ]] || abort "Preceding failure was detected by '${FUNCNAME[0]}'."
    local _path="${1}" _level="${2:-1}"
    local _err
    info "args:'${*}'"
    if [[ ! "${_path}" == .* ]]; then
      abort "Path was not valid:(${_path}), it must start with a '.'"
    fi
    if [[ "${_path}" == "." ]]; then
      abort "Root does not have a parent.:(${_path})"
    fi
    _err="$(mktemp)"
    jq -r -c -n -L "${JF_BASEDIR}/lib" \
      'import "shared" as shared;
      .|path('"${_path}"')|.[0:-'"${_level}"']|shared::path2pexp(.)' 2>"${_err}" ||
      abort "$(printf \
        "Error was reported for node path:'${_path}' and level:'${_level}' by jq command. Forgot quoting?:\n%s" \
        "$(cat "${_err}")")"
  }

  function array_append() {
    # shellcheck disable=SC2181
    [[ $? == 0 ]] || abort "Preceding failure was detected by '${FUNCNAME[0]}'."
    [[ $# -gt 0 ]] || abort "No argument was given to built-in:'array_append'"
    local _cur="${1}"
    local _i
    shift
    info "args:'${*}'"
    for _i in "${@}"; do
      _cur="$(_array_append "${_cur}" "${_i}")"
    done
    echo "${_cur}"
  }

  function _array_append() {
    info "jq -r -c -n"
    info "--argjson a '${1}'"
    info "--argjson b '${2}'"
    # shellcheck disable=SC2154
    info "'\$a + \$b'"
    jq -r -c -n --argjson a "${1}" --argjson b "${2}" '$a + $b'
  }

  function error() {
    abort "${@}"
  }
}
