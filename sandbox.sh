set -E -eu
# set -o posix

function func1() {
  cat "${1}"
}
function fname() {
  if [[ "${1}" == "missing" ]]; then
    return 1
  fi
  echo "$1"
}
declare var
export  -f func1
export  -f fname
var=$(func1 "${1}")
echo "var=${var}"

echo "finished"
