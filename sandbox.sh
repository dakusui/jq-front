#!/bin/bash
set -eu -o pipefail -E
shopt -s inherit_errexit

function func1() {
  local arg="${1}"
  echo "(func1)This line shouldn't be reached:arg='${arg}': '${?}'" >&2
}

function func2() {
  echo "value from func2"
  return 1
}

read var < <(func1 "$(func2)")
echo "main:This line shouldn't be reached:var='${var}':'${?}'" >&2
