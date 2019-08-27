#!/bin/bash -eu

function all_path() {
  local _json="${1}"
  echo "${_json}" | jq -r -c 'path(..)|[.[]]|map(if type=="number" then "["+tostring+"]" else "\""+tostring+"\"" end)|join(".")|gsub("\\.\\[";"[")|"."+tostring'
}

function value_at() {
  local _path="${1}"
  local _json="${2}"
  echo "_path=${1},_json=${2}" >&2
  echo "${_json}" | jq "${_path}"
}

function read_json_from_path() {
  local _name="${1}"
  jq -c . "${_name}"
}

function remove_meta_nodes() {
  local _target="${1}"
  local _cur="$(mktemp)"
  cp "${_target}" "${_cur}"
  for i in $(all_path "$(cat "${_target}")" | grep '"$extends"$'); do
    local _next="$(mktemp)"
    jq ".|del(${i})" "${_cur}" > "${_next}"
    _cur="${_next}"
  done
  cat "${_cur}"
}

function merge_object_nodes() {
  local _a="${1}"
  local _b="${2}"
  jq -s '.[0] * .[1]' "${_a}" "${_b}"
}

function expand_external_inheritances() {
  local _target="${1}"
  local _cur="$(mktemp)"
  echo '{}' > "${_cur}"
  for i in $(value_at '.["$extends"][]' "${_target}"); do
    echo "i=<$i>" >&2
    local _next=$(mktemp)
    local _tmp=$(mktemp)
    echo "...reading" >&2
    read_json_from_path "$i" > "${_tmp}"
    echo "...read" >&2
    echo "...merging"
    merge_object_nodes "${_cur}" "${_tmp}" > "${_next}"
    echo "...merged" >&2
    _cur="${_next}"
  done
  jq -r -c . "${_cur}"
}

function expand_internal_inheritances() {
  local _target="${1}"
  local _cur="$(mktemp)"
  echo '{}' > "${_cur}"
  for i in $(all_path "$(cat ${_target})" | grep '"$extends"$'); do
    local _next="$(mktemp)"
    for j in $(jq -r -c "$i[]" "${_target}"); do
      jq -n "input | ${i%.\"\$extends\"}=input" "${_cur}" "${j}" > "${_next}"
      _cur="${_next}"
    done;
  done
  jq -r -c . "${_cur}"
}

function expand_json() {
  local _target="${1}"
  local _extends="$(mktemp)"
  local _clean="$(mktemp)"

  expand_internal_inheritances "${_target}" > "${_extends}"
  remove_meta_nodes "${_target}" > "${_clean}"
  merge_object_nodes "${_clean}" "${_extends}"
}
