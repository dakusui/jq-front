set -eu

function func1() {
  echo "func1:$1"
  func2 "${1}"
}

function func2() {
  echo "func2:$1"
  func3 $1
}

function func3() {
  echo "func3:$1"
  return $1
}
#a=$(func1 "$(func2 "$1")")
func1 "${1}" || {
  echo "return code=$?"
  exit 1
}

a=$(func1 "$1")
echo finished "$a"
