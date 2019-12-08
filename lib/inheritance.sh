set -eu
[[ "${_INHERITANCE_SH:-""}" == "yes" ]] && return 0
_INHERITANCE_SH=yes

function expand_inheritances() {
  local _nodeentry="${1}" _validation_mode="${2}" _jf_path="${3}"
  local _caching_filename _norm_nodeentry
  perf "begin: ${_nodeentry}"
  _norm_nodeentry="$(_normalize_nodeentry "${_nodeentry}" "${_jf_path}")"
  _check_cyclic_dependency "${_norm_nodeentry}" inheritance
  _caching_filename="${_JF_POOL_DIR}/$(hashcode "${_norm_nodeentry}")"
  [[ -e "${_caching_filename}" ]] || {
    perf "cache miss: expanding inheritances for nodeentry: '${_norm_nodeentry}'"
    _expand_inheritances "${_norm_nodeentry}" "${_validation_mode}" "${_jf_path}" >"${_caching_filename}"
  }
  cat "${_caching_filename}"
  _unmark_as_in_progress "${_norm_nodeentry}" inheritance
  perf "end: ${_nodeentry} (cached in ${_caching_filename})"
}

function _expand_inheritances() {
  local _nodeentry="${1}" _validation_mode="${2}" _jf_path="${3}"
  local _materialized_file _content _jsonized_content _out _absfile
  local -a _specifier
  perf "begin: ${_nodeentry}"

  mapfile -d ';' -t _specifier <<<"$(_normalize_nodeentry "${_nodeentry}" "${_jf_path}")"
  _absfile="$(search_file_in "${_specifier[0]}" "${_jf_path}")"
  _jsonized_content="$(jsonize "${_absfile}" "${_specifier[1]}" "$(join_by ';' "${_specifier[@]:2}")")"
  # Fail on command substitution cannot be checked directly
  # shellcheck disable=SC2181
  [[ $? == 0 ]] || abort "Failed to convert a file:'${_absfile}' into to a json."
  _materialized_file="$(mktemp_with_content "${_jsonized_content}")"
  validate_jf_json "${_materialized_file}" "${_validation_mode}"
  _content="${_jsonized_content}"
  #----
  if ! is_json "${_content}"; then
    abort "Malformed JSON was given:'${_nodeentry}': _materialized_file='${_materialized_file}', _content='${_content}'"
  fi
  if is_object "${_content}"; then
    local _tmp _local_nodes_dir _c _expanded
    ####
    # Strangely the line above does not causes a quit on a failure.
    # Explitly check and abotrt this functino.
    _c="$(expand_filelevel_inheritances "${_materialized_file}" "${_validation_mode}" "$(dirname "${_absfile}"):${_jf_path}")" ||
      abort "File-level expansion failed for '${_nodeentry}'"
    _tmp="$(mktemp_with_content "${_c}")"
    _local_nodes_dir=$(materialize_local_nodes "${_tmp}")
    expand_inheritances_of_local_nodes "${_local_nodes_dir}" \
      "${_local_nodes_dir}:${_jf_path}"
    _expanded="$(expand_nodelevel_inheritances "${_tmp}" \
      "${_validation_mode}" \
      "${_local_nodes_dir}:$(dirname "${_absfile}"):${_jf_path}")" ||
      abort "Failed to expand node level inheritance for '${_nodeentry}'(3)"
    _out=$(mktemp_with_content "${_expanded}")
  else
    : # Clear $?
    _out="$(mktemp_with_content "${_content}")"
  fi
  cat "${_out}"
  perf "end: ${_nodeentry}"
}

function expand_filelevel_inheritances() {
  local _materialized_file="${1}" _validation_mode="${2}" _path="${3}"
  ####
  # This is intentionally using single quotes to pass quoted path expression to jq.
  # shellcheck disable=SC2016
  local _in _cur _content
  perf "begin:${_materialized_file}"
  _in="${_materialized_file}"
  _content="$(cat "${_in}")"
  _cur="${_content}"
  if is_object "${_content}"; then
    # shellcheck disable=SC2016
    # this is intentionally suppressing expansion to pass the value to jq.
    if has_value_at '."$extends"' "${_content}"; then
      local i
      while IFS= read -r i; do
        local _c _parent
        _parent="$(expand_inheritances "$(_normalize_nodeentry "${i}" "${_path}")" "${_validation_mode}" "${_path}")"
        _c="$(_merge_object_nodes "${_parent}" "${_cur}")"
        # Cannot check the exit code directly because of command substitution
        # shellcheck disable=SC2181
        [[ $? == 0 ]] || abort "Failed to merge file:'${i}' with content:'${_cur}'"
        _cur="${_c}"
      done <<<"$(value_at '."$extends"[]' "${_content}")"
    fi
    local _cur_tmpfile
    _cur_tmpfile="$(mktemp_with_content "${_cur}")"
    jq -r -c '.|del(.["$extends"])' "${_cur_tmpfile}"
  else
    message "WARN: array expansion is not yet implemented."
    echo "${_content}"
  fi
  perf "end:${_materialized_file}"
}

function expand_inheritances_of_local_nodes() {
  local _path="${1}" _jf_path="${2}"
  debug "begin: _path=${_path}"
  while IFS= read -r -d '' i; do
    local _tmp
    local _f="${i}"
    debug "expanding inheritance of a local node:'${i}'"
    _tmp="$(mktemp_with_content "$(expand_inheritances "${_f}" "no" "${_path}:${_jf_path}")")"
    cp "${_tmp}" "${_f}"
    debug "...expanded"
  done < <(find "${_path}" -maxdepth 1 -type f -print0)
  debug "end"
}

function expand_nodelevel_inheritances() {
  local _target="${1}" _validation_mode="${2}" _path="${3}"
  local _expanded _expanded_clean _clean _content _ret
  perf "begin:_target=${_target}"
  _content="$(cat "${_target}")"
  _expanded="$(_expand_nodelevel_inheritances "${_content}" "${_validation_mode}" "${_path}")" ||
    abort "Failed to expand node level inheritance for file:'${_target}'(1)"
  _clean="$(_remove_meta_nodes "${_content}")"
  _expanded_clean="$(_remove_meta_nodes "${_expanded}")"
  _ret=$(_merge_object_nodes "${_expanded_clean}" "${_clean}") || abort "Failed to expand node level inheritance for file:'${_target}'(content:'${_content}')(2)"
  echo "${_ret}"
  perf "end"
}

function _expand_nodelevel_inheritances() {
  local _content="${1}" _validation_mode="${2}" _path="${3}"
  local _cur _in i
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
    local j _p="${i%.\"\$extends\"}"
    local -a _extendeds
    mapfile -t _extendeds < <(echo "${_content}" | jq -r -c "${i}[]") || _extendeds=()
    for j in "${_extendeds[@]}"; do
      local _jj _cur_content _tmp_content
      debug "processing nodeentry: '${j}'"
      _jj="$(_normalize_nodeentry "${j}" "${_path}")" || abort "Failed to locate file '${j}'"
      local _next_content
      _next_content="$(read_json_from_nodeentry "${_jj}")"
      is_json "${_next_content}" || abort "Malformed JSON was given:'${_jj}'='${_next_content}'"
      _cur_content="$(cat "${_cur}")"
      local _merged_piece_content
      if has_value_at "${_p}" "${_cur_content}"; then
        local _cur_piece _next_piece
        _cur_piece="$(echo "${_cur_content}" | jq "${_p}")"
        _next_piece="$(expand_inheritances "${_jj}" "${_validation_mode}" "${_path}")"
        _merged_piece_content="$(_merge_object_nodes "${_cur_piece}" "${_next_piece}")"
        # shellcheck disable=SC2181
        [[ $? == 0 ]] || abort "Failed to merge file:'${_cur}' with _nodeentry:'${_jj}'"
      else
        local _expanded_tmp
        _expanded_tmp="$(expand_inheritances "${_jj}" "${_validation_mode}" "${_path}")"
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
  local _target="${1}"
  local _content _ret
  debug "begin"
  _content="$(cat "${_target}")"
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
