FROM ubuntu:18.04
ARG VERSION=unknown
RUN apt-get update && \
    apt-get install jq -y && \
    apt-get install npm -y && \
    apt-get install python -y && \
    apt-get install python-pip -y && \
    pip install yq && \
    npm install -g ajv-cli && \
    mkdir -p /var/lib/jq-front && \
    mkdir -p /app/lib && \
    mkdir -p /app/schema && \
    echo $VERSION > /app/version_file
COPY ./jq-front /app
COPY ./build_info.sh /app
COPY ./build_info.json /app
COPY ./lib /app/lib
COPY ./schema /app/schema
ENTRYPOINT ["/app/jq-front"]
CMD []
