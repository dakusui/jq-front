set -eu

function func1() {
  echo "funcName:func1"
  return "${1}"
}

function func2() {
  echo "funcName:func2" >&2
  echo "$1"
  return $1
}
a=$(func1 "$(func2 "$1")")

echo finished "${a}"