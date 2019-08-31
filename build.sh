# Run tests
set -eu

echo "DOCUMENT:"
docker run -it \
       --user 1000:1000 \
       -v "$(pwd)":/documents/ \
       asciidoctor/docker-asciidoctor \
       asciidoctor -r asciidoctor-diagram README.adoc -o docs/index.html
echo "...DONE"
echo ""

echo "TESTING:"
bash -eu "tests/tests.sh" "$(pwd)/jf" "$(pwd)/tests"
echo "...DONE"
echo ""

echo "BUILDING DOCKER IMAGE:"
docker build -t dakusui/jf .
echo "...DONE"
echo ""

