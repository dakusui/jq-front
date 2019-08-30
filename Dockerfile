
From ubuntu:18.04
RUN apt-get update && \
    apt-get install jq -y && \
    mkdir -p /var/lib/jf && \
    mkdir -p /app
COPY ./jf /app
ENTRYPOINT ["/app/jf"]
CMD []

# docker run -i -v /:/var/lib/jf jf "var/lib/jf/$(pwd)/examples/A.json"
# TODO: mangle JF_PATH environment variable
# TODO: define an alias that takes care of JF_PATH and invokes the command line above.
