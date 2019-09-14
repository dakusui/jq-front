#!/bin/bash
set -eu -o pipefail -E
shopt -s inherit_errexit

function func1() {
  echo "FUNC1"
  exit 1
}

function func2() {
  local ret
  ret=$(func1)
  echo $ret
  echo "(func2)This line shouldn't be reached:'${?}'" >&2
}

var=$(func2)
echo "main:This line shouldn't be reached:'${var}':'${?}'" >&2
