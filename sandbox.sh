set -E -eu
# set -o posix

function func1() {
  cat "${1}"
}

declare -a arr
arr=(HELLO WORLD)

func2 "hello" "${arr[@]}" asdf

