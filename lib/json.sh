[[ "${_JSON_SH:-""}" == "yes" ]] && return 0
_JSON_SH=yes

function _remove_meta_nodes() {
  local _content="${1}"
  if is_object "${_content}"; then
    local _keys i
    # Intentional single quote to find a keyword that starts with '$'
    # shellcheck disable=SC2016
    mapfile -t _keys < <(_paths_of_extends "${_content}") || _keys=()
    for i in "${_keys[@]}"; do
      local _next
      _next="$(echo "${_content}" | jq ".|del(${i})")"
      _content="${_next}"
    done
  fi
  echo "${_content}"
}

function _paths_of_extends() {
  local _content="${1}"
  echo "${_content}" | jq -r -c -L "${JF_BASEDIR}/lib" '#---
import "shared" as shared;

[paths(..)|. as $p|.[-1]|select(tostring=="$extends")|$p]
              |sort
              |sort_by(length)
              |.[]
              |shared::path2pexp(.)'
}

function validate_jf_json() {
  local _content="${1}" _mode="${2}"
  if [[ "${_mode}" == "no" ]]; then
    debug "validation skipped"
    return 0
  elif [[ "${_mode}" == "strict" ]]; then
    _validate_jf_json_with "$(mktemp_with_content "${_content}")" "strict"
  elif [[ "${_mode}" == "lenient" ]]; then
    _validate_jf_json_with "$(mktemp_with_content "${_content}")" "lenient"
  else
    abort "Unknown validation mode:'${_mode}' was set."
  fi
  return $?
}

function _validate_jf_json_with() {
  validate_json "${1}" "${_JF_SCHEMA_DIR}/${2}.json"
}

function validate_json() {
  local _in="${1}" _schema_file="${2}"
  local _out=
  {
    local _ret
    debug "validating: '${_in}'"
    _out=$(ajv validate -s "${_schema_file}" -d "${_in}" 2>&1)
    _ret=$?
    debug "...validated: '${_out}'"
    return "${_ret}"
  } || {
    abort "Validation by ajv for '${_in}' was failed:\n${_out}"
  }
}

function is_object() {
  local _json_content="${1}"
  local _ret
  is_debug_enabled && debug "_json_content:'${_json_content}'"
  _ret="$(echo "${_json_content}" | jq '.|if type=="object" then 0 else 1 end' 2>/dev/null)"
  [[ "${_ret}" == "" ]] &&
    abort "Probably jq wrote something other than numeric value from the content:'$(trim "${_json_content}")'."
  return "${_ret}"
}

function type_of() {
  local _json_content="${1}"
  jq -r -c '.|type' <(echo "${_json_content}") || echo "string"
}

function has_value_at() {
  local _path="${1}"
  local _json="${2}"
  local _val
  _val=$(echo "${_json}" | jq "${_path}|select(.)") || return 1
  if [[ -z ${_val} ]]; then
    return 1
  else
    return 0
  fi
}

function value_at() {
  local _path="${1}" # A path from which the output is retrieved.
  local _json="${2}" # JSON content
  local _default="${3:-}"
  local _filter="${4:-.}"
  local _ret
  _ret="$(
    echo "${_json}" | jq -r -c "${_path}|select(.)" 2>/dev/null
  )"
  if [[ -z "${_ret}" ]]; then
    if [[ -z "${_default}" ]]; then
      abort "Failed to access '${_path}' and default value for it was not given."
    else
      echo "${_default}" | jq -r -c "${_filter}"
    fi
  else
    echo "${_ret}"
  fi
}

# Latter overrides former
function merge_object_nodes() {
  local _a="${1}" _b="${2}"
  local _error
  _error=$(mktemp)
  perf "begin"
  [[ "${_a}" != '' ]] || abort "An empty string was given as _a"
  [[ "${_b}" != '' ]] || abort "An empty string was given as _b"
  is_debug_enabled && debug "merging _a:'${_a}' and _b:'${_b}'"
  # shellcheck disable=SC2016
  jq -r -c -n --argjson a "${_a}" --argjson b "${_b}" -L "${JF_BASEDIR}/lib" \
    'import "shared" as shared;
    def value_at($n; $p):
      $n | getpath($p);

    def setvalue_at($n; $p; $v):
      def type_of($v):
        $v | type;
      def _setvalue_at($n; $p; $v):
        $n | try setpath($p; $v)
             catch error("Failed to process node at path:<\($p|shared::path2pexp(.))>; the value:<\($v)>).");
      $n | if type_of($v)=="object" or type_of($v)=="array" then
             if type_of(value_at($n; $p))!="object" and type_of(value_at($n; $p)!="array") then
               _setvalue_at(.;$p; $v)
             else
               .
             end
           else
             _setvalue_at(.; $p; $v)
           end;

    def merge_objects($a; $b):
      $b | [paths(scalars_or_empty)]
         | reduce .[] as $p ($a; setvalue_at(.; $p; value_at($b; $p)));

    merge_objects($a; $b)' 2>"${_error}" || {
    abort "$(printf "jq-front: Failed to merge object nodes:\n    a=<%s>\n    b=<%s>\nERROR: %s)" \
      "$(jq -r -c -n "${_a}|." || echo "MALFORMED: ${_a}")" \
      "$(jq -r -c -n "${_b}|." || echo "MALFORMED: ${_b}")" \
      "$(cat "${_error}" || echo "UNAVAILABLE")")"
  }
  perf "end"
}
