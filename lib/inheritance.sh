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
    local _local_nodes_dir _c _expanded
    ####
    # Strangely the line above does not causes a quit on a failure.
    # Explitly check and abotrt this functino.
    _c="$(expand_filelevel_inheritances "${_jsonized_content}" "${_validation_mode}" "$(dirname "${_absfile}"):${_jf_path}")" ||
      abort "File-level expansion failed for '${_nodeentry}'"
    debug "_nodeentry='${_nodeentry}', _absfile='${_absfile}'"
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
  local _content="${1}" _validation_mode="${2}" _path="${3}"
  ####
  # This is intentionally using single quotes to pass quoted path expression to jq.
  # shellcheck disable=SC2016
  local _cur
  perf "begin"
  is_debug_enabled && debug "content='${_content}'"
  _cur="${_content}"
  local -a _parents
  # shellcheck disable=SC2016 # Intentional
  mapfile -t _parents <<<"$(value_at '."$extends"[]' "${_content}" '[]' '.[]')"
  if ! is_effectively_empty_array "${_parents[@]}"; then
    local i
    for i in "${_parents[@]}"; do
      local _c _parent
      _parent="$(nodepool_read_nodeentry "${i}" "${_validation_mode}" "${_path}")"
      _c="$(merge_object_nodes "${_parent}" "${_cur}")"
      # Cannot check the exit code directly because of command substitution
      # shellcheck disable=SC2181
      [[ $? == 0 ]] || abort "Failed to merge file:'${i}' with content:'$(trim "${_cur}")'"
      _cur="${_c}"
    done
  fi
  echo "${_cur}" | jq -r -c '.|del(.["$extends"])'
  perf "end"
}

function expand_inheritances_for_local_nodes() {
  local _local_nodes_dir="${1}" _jf_path="${2}"
  debug "begin: _local_nodes_dir=${_local_nodes_dir}"
  while IFS= read -r -d '' i; do
    local _f="${i}"
    debug "expanding inheritance of a local node:'${i}'"
    mktemp_with_content "$(nodepool_read_nodeentry """${_f}""" "no" "${_local_nodes_dir}:${_jf_path}")" >"${_f}"
    debug "...expanded"
  done < <(find "${_local_nodes_dir}" -maxdepth 1 -type f -print0)
  debug "end"
}

function expand_nodelevel_inheritances() {
  local _content="${1}" _validation_mode="${2}" _path="${3}"
  local _expanded _expanded_clean _clean _content _ret
  perf "begin"
  _expanded="$(_expand_nodelevel_inheritances "${_content}" "${_validation_mode}" "${_path}")" ||
    abort "Failed to expand node level inheritance for node:'$(trim "${_content}")'(1)"
  _clean="$(_remove_meta_nodes "${_content}")"
  _expanded_clean="$(_remove_meta_nodes "${_expanded}")"
  _ret=$(merge_object_nodes "${_expanded_clean}" "${_clean}") ||
    abort "Failed to expand node level inheritance for node:'$(trim "${_content}")'(2)"
  echo "${_ret}"
  perf "end"
}

function _expand_nodelevel_inheritances() {
  local _content="${1}" _validation_mode="${2}" _path="${3}"
  local _cur='{}' i
  local -a _keys
  perf "begin"
  is_debug_enabled && debug "_content='${_content}'"
  # Intentional single quote to find a keyword that starts with '$'
  # shellcheck disable=SC2016
  mapfile -t _keys < <(_paths_of_extends "${_content}")
  is_effectively_empty_array "${_keys[@]}" && _keys=()
  for i in "${_keys[@]}"; do
    local _jj _p="${i%.\"\$extends\"}"
    local -a _extendeds
    mapfile -t _extendeds < <(echo "${_content}" | jq -r -c "${i}[]")
    is_effectively_empty_array "${_extendeds[@]}" && _extendeds=()
    for _jj in "${_extendeds[@]}"; do
      local _tmp_content
      debug "processing nodeentry: '${_jj}'"
      local _merged_piece_content
      if has_value_at "${_p}" "${_cur}"; then
        local _cur_piece _next_piece
        _cur_piece="$(echo "${_cur}" | jq -r -c "${_p}")"
        _next_piece="$(nodepool_read_nodeentry "${_jj}" "${_validation_mode}" "${_path}")"
        _merged_piece_content="$(merge_object_nodes "${_next_piece}" "${_cur_piece}")"
        # shellcheck disable=SC2181
        [[ $? == 0 ]] || abort "Failed to merge node:'$(trim "${_cur}")' with _nodeentry:'${_jj}'"
      else
        local _expanded_tmp
        _expanded_tmp="$(nodepool_read_nodeentry "${_jj}" "${_validation_mode}" "${_path}")"
        # shellcheck disable=SC2181
        [[ $? == 0 ]] || abort "Failed to expand inheritances for '${_jj}'"
        _merged_piece_content="${_expanded_tmp}"
      fi
      is_debug_enabled && debug "_merged_piece_content:'${_merged_piece_content}'"
      _tmp_content="$(jq -n "input | ${_p}=input" <(echo "${_cur}") <(echo "${_merged_piece_content}"))"
      _cur="${_tmp_content}"
      is_debug_enabled && debug "_cur(updated):'${_cur}'"
    done
  done
  perf "end"
  echo "${_cur}" | jq -r -c .
}

function materialize_local_nodes() {
  local _content="${1}"
  local _ret _i
  debug "begin"
  _ret="$(mk_localnodedir)"
  # Quickfix for Issue #98: Probably we should filter null, which can be produced by the first predicate (."$local")
  for _i in $(echo "${_content}" | jq -r -c '."$local"
    |. as $local
    |keys[]
    |. as $k
    |$local|getpath([$k])
           |. as $v
           |[$k, $v]' 2>/dev/null); do
    echo "${_i}" | jq -c '.[1]' >"${_ret}/$(echo "${_i}" | jq -r -c '.[0]')"
  done
  echo "${_ret}"
  debug "end"
}
