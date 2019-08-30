# Run tests
set -eu

echo "TESTING:"
bash -eu "tests/tests.sh" "$(pwd)/jf" "$(pwd)/tests"

echo ""

echo "BUILDING DOCKER IMAGE:"
docker build -t jf .

