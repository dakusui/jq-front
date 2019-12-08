set -eu
[[ "${_INHERITANCE_SH:-""}" == "yes" ]] && return 0
_INHERITANCE_SH=yes

function expand_inheritances() {
  local _nodeentry="${1}" _validation_mode="${2}" _jf_path="${3}"
  local _jsonized_content _out _absfile
  local -a _specifier
  perf "begin: ${_nodeentry}"

  mapfile -d ';' -t _specifier <<<"$(_normalize_nodeentry "${_nodeentry}" "${_jf_path}")"
  _absfile="$(search_file_in "${_specifier[0]}" "${_jf_path}")"
  _jsonized_content="$(jsonize "${_absfile}" "${_specifier[1]}" "$(join_by ';' "${_specifier[@]:2}")")"
  # Fail on command substitution cannot be checked directly
  # shellcheck disable=SC2181
  [[ $? == 0 ]] || abort "Failed to convert a file:'${_absfile}' into to a json."
  validate_jf_json "${_jsonized_content}" "${_validation_mode}"
  if is_object "${_jsonized_content}"; then
    local _tmp _local_nodes_dir _c _expanded
    ####
    # Strangely the line above does not causes a quit on a failure.
    # Explitly check and abotrt this functino.
    _c="$(expand_filelevel_inheritances "${_jsonized_content}" "${_validation_mode}" "$(dirname "${_absfile}"):${_jf_path}")" ||
      abort "File-level expansion failed for '${_nodeentry}'"
    _local_nodes_dir=$(materialize_local_nodes "${_c}")
    expand_inheritances_for_local_nodes "${_local_nodes_dir}" "${_jf_path}"
    _expanded="$(expand_nodelevel_inheritances "${_c}" \
      "${_validation_mode}" \
      "${_local_nodes_dir}:$(dirname "${_absfile}"):${_jf_path}")" ||
      abort "Failed to expand node level inheritance for '${_nodeentry}'(3)"
    _out="${_expanded}"
  else
    : # Clear $?
    _out="${_jsonized_content}"
  fi
  echo "${_out}"
  perf "end: ${_nodeentry}"
}

function expand_filelevel_inheritances() {
  local _materialized_content="${1}" _validation_mode="${2}" _path="${3}"
  ####
  # This is intentionally using single quotes to pass quoted path expression to jq.
  # shellcheck disable=SC2016
  local _cur
  perf "begin"
  debug "content='${_materialized_content}'"
  _cur="${_materialized_content}"
  if is_object "${_materialized_content}"; then
    # shellcheck disable=SC2016
    # this is intentionally suppressing expansion to pass the value to jq.
    if has_value_at '."$extends"' "${_materialized_content}"; then
      local i
      while IFS= read -r i; do
        local _c _parent
        _parent="$(nodepool_read_nodeentry "${i}" "${_validation_mode}" "${_path}")"
        _c="$(_merge_object_nodes "${_parent}" "${_cur}")"
        # Cannot check the exit code directly because of command substitution
        # shellcheck disable=SC2181
        [[ $? == 0 ]] || abort "Failed to merge file:'${i}' with content:'${_cur}'"
        _cur="${_c}"
      done <<<"$(value_at '."$extends"[]' "${_materialized_content}")"
    fi
    echo "${_cur}" | jq -r -c '.|del(.["$extends"])'
  else
    message "WARN: array expansion is not yet implemented."
    echo "${_materialized_content}"
  fi
  perf "end"
}

function expand_inheritances_for_local_nodes() {
  local _local_nodes_dir="${1}" _jf_path="${2}"
  debug "begin: _local_nodes_dir=${_local_nodes_dir}"
  while IFS= read -r -d '' i; do
    local _tmp _f="${i}"
    debug "expanding inheritance of a local node:'${i}'"
    _tmp="$(mktemp_with_content "$(nodepool_read_nodeentry "${_f}" "no" "${_local_nodes_dir}:${_jf_path}")")"
    cp "${_tmp}" "${_f}"
    debug "...expanded"
  done < <(find "${_local_nodes_dir}" -maxdepth 1 -type f -print0)
  debug "end"
}

function expand_nodelevel_inheritances() {
  local _materialized_content="${1}" _validation_mode="${2}" _path="${3}"
  local _expanded _expanded_clean _clean _content _ret
  perf "begin"
  _expanded="$(_expand_nodelevel_inheritances "${_materialized_content}" "${_validation_mode}" "${_path}")" ||
    abort "Failed to expand node level inheritance for node:'${_materialized_content}'(1)"
  _clean="$(_remove_meta_nodes "${_materialized_content}")"
  _expanded_clean="$(_remove_meta_nodes "${_expanded}")"
  _ret=$(_merge_object_nodes "${_expanded_clean}" "${_clean}") ||
    abort "Failed to expand node level inheritance for node:'${_materialized_content}'(2)"
  echo "${_ret}"
  perf "end"
}

function _expand_nodelevel_inheritances() {
  local _content="${1}" _validation_mode="${2}" _path="${3}"
  local _cur i
  local -a _keys
  perf "begin"
  debug "_content='${_content}'"
  _cur=$(mktemp_with_content '{}')
  # Intentional single quote to find a keyword that starts with '$'
  # shellcheck disable=SC2016
  mapfile -t _keys < <(_paths_of_extends "${_content}") || _keys=()
  # shellcheck disable=SC2181
  [[ $? == 0 ]] || abort "Node-level expansion was failed for node:'${_content}'"
  for i in "${_keys[@]}"; do
    local _jj _p="${i%.\"\$extends\"}"
    local -a _extendeds
    mapfile -t _extendeds < <(echo "${_content}" | jq -r -c "${i}[]") || _extendeds=()
    for _jj in "${_extendeds[@]}"; do
      local _cur_content _tmp_content
      debug "processing nodeentry: '${_jj}'"
      _cur_content="$(cat "${_cur}")"
      local _merged_piece_content
      if has_value_at "${_p}" "${_cur_content}"; then
        local _cur_piece _next_piece
        _cur_piece="$(jq "${_p}" "${_cur}")"
        _next_piece="$(nodepool_read_nodeentry "${_jj}" "${_validation_mode}" "${_path}")"
        _merged_piece_content="$(_merge_object_nodes "${_cur_piece}" "${_next_piece}")"
        # shellcheck disable=SC2181
        [[ $? == 0 ]] || abort "Failed to merge file:'${_cur}' with _nodeentry:'${_jj}'"
      else
        local _expanded_tmp
        _expanded_tmp="$(nodepool_read_nodeentry "${_jj}" "${_validation_mode}" "${_path}")"
        # shellcheck disable=SC2181
        [[ $? == 0 ]] || abort "Failed to expand inheritances for '${_jj}'"
        _merged_piece_content="${_expanded_tmp}"
      fi
      _tmp_content="$(jq -n "input | ${_p}=input" "${_cur}" <(echo "${_merged_piece_content}"))"
      _cur=$(mktemp_with_content "${_tmp_content}") ||
        abort "Failure detected during creation of a temporary file for file:'${_cur}'"
    done
  done
  perf "end"
  jq -r -c . "${_cur}"
}

function materialize_local_nodes() {
  local _content="${1}"
  local _ret
  debug "begin"
  _ret="$(mktemp -d)"
  # Intentional single quotes for jq.
  # shellcheck disable=SC2016
  if has_value_at '."$local"' "${_content}"; then
    # shellcheck disable=SC2016
    for i in $(keys_of '."$local"' "${_content}"); do
      echo "${_content}" | jq '."$local".''"'"${i}"'"' >"${_ret}/${i}"
    done
  fi
  echo "${_ret}"
  debug "end"
}
