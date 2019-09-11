set -eu
. lib/shared.sh

function _render_text_node() {
  local _node_value="${1}"
  local _mode="raw"
  local _body
  local _ret
  debug "rendering"
  if [[ "${_node_value}" == *:* ]]; then
    _mode="${_node_value%%:*}"
    _body="${_node_value#*:}"
  else
    _body="${_node_value}"
  fi

  if [[ "${_mode}" == "template" ]]; then
    _ret=$(eval echo "${_body}")
  elif [[ "${_mode}" == "raw" ]]; then
    _ret="${_body}"
  fi
  debug "rendered:_mode='${_mode}'"
  echo "\"${_ret}\""
}

function _type_of() {
  local _path="${1}"
  local _content="${2}"
  echo "${_content}" | jq -r -c "${_path}|type"
}

function _paths_type_of() {
  local _type="${1}"
  local _content="${2}"
  local i
  local -a _paths
  debug "scanning _type=${_type},_content=${_content}"
  mapfile -t _paths < <(all_paths "${_content}")
  for i in "${_paths[@]}"; do
    local _t
    _t="$(_type_of "${i}" "${_content}")"
    if [[ "${_t}" == "${_type}" ]]; then
      debug "    read:'${i}'"
      echo "${i}"
    fi
  done
  debug "scanned"
}

function _perform_templating() {
  local _content="${1}"
  local _ret
  local i
  local -a _keys
  debug "templating"
  mapfile -t _keys < <(_paths_type_of "string" "${_content}")
  debug "splitted"
  for i in "${_keys[@]}"; do
    local _node_value
    local _templated_node_value
    debug "processing:${i}"
    _node_value="$(value_at "${i}" "${_content}")"
    _templated_node_value="$(_render_text_node "${_node_value}")"
    if [[ -z "${_ret+empty}" ]]; then
      debug "first node:'${i}':'${_templated_node_value}'"
      _ret="$(jq -r -c -n "${i}=input" "$(mktemp_with_content "${_templated_node_value}")")"
    else
      local _a
      local _b
      debug "node:'${_ret}':'${i}':'${_templated_node_value}'"
      _a=$(mktemp_with_content "${_ret}")
      _b=$(mktemp_with_content "${_templated_node_value}")
      _ret="$(jq -r -c -n "input|${i}=input" "${_a}" "${_b}")"
    fi
    debug "processed:${i}"
  done
  debug "templated:'${_ret}'"
  echo "${_ret}"
}

function main() {
  local _content
  _content="$(cat "${1}")"
  _perform_templating "${_content}"
}

main "$@"
