FROM ubuntu:18.04
ARG VERSION=unknown
RUN apt-get update && \
    apt-get install jq -y && \
    apt-get install npm -y && \
    npm install -g ajv-cli && \
    npm install -g yamljs && \
    mkdir -p /var/lib/jq-front && \
    mkdir -p /app/lib && \
    mkdir -p /app/schema && \
    apt-get autoremove -y && \
    echo $VERSION > /app/version_file
COPY ./jq-front /app
COPY ./build_info.sh /app
COPY ./build_info.json /app
COPY ./lib /app/lib
COPY ./schema /app/schema
COPY ./bin /usr/local/bin
ENTRYPOINT ["/app/jq-front"]
CMD []
