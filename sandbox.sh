set -eu

function func1() {
  echo "func1:$1" >&2
  func2 "${1}"
}

function func2() {
  echo "func2:$1" >&2
  func3 $1
  return 0
}

function func3() {
  echo "func3:$1" >&2
  return $1
}

a=$(func1 "$1")
echo finished "---->'$a:$?'"
