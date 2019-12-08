set -eu
[[ "${_JSON_SH:-""}" == "yes" ]] && return 0
_JSON_SH=yes

function _remove_meta_nodes() {
  local _content="${1}"
  local _cur
  if is_object "${_content}"; then
    local _keys i
    _cur="$(mktemp_with_content "${_content}")"
    # Intentional single quote to find a keyword that starts with '$'
    # shellcheck disable=SC2016
    mapfile -t _keys < <(_paths_of_extends "${_content}") || _keys=()
    for i in "${_keys[@]}"; do
      local _next
      _next="$(mktemp_with_content "$(jq ".|del(${i})" "${_cur}")")"
      _cur="${_next}"
    done
    cat "${_cur}"
  else
    echo "${_content}"
  fi
}

function _paths_of_string_type() {
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
  local _in="${1}" _mode="${2}"
  if [[ "${_mode}" == "no" ]]; then
    debug "validation skipped"
    return 0
  elif [[ "${_mode}" == "strict" ]]; then
    _validate_jf_json_with "${_in}" "strict"
  elif [[ "${_mode}" == "lenient" ]]; then
    _validate_jf_json_with "${_in}" "lenient"
  else
    abort "Unknown validation mode:'${_mode}' was set."
  fi
  return $?
}

function _validate_jf_json_with() {
  validate_json "${1}" "${_JF_SCHEMA_DIR}/${2}.json"
}
