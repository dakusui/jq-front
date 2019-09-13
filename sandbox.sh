#!/bin/bash

function func1() {
  func2
}

function func2() {
  local v=${1:-0}
  if [[ ${v} == 0 ]]; then
    func2 1
  fi
  cat "$f"
}


f="${1}"
var=$(func1)
[[ $? == 0 ]] || echo "code=$?:${var}"

echo bye:${var}
