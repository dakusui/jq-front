FROM ubuntu:18.04
RUN apt-get update && \
    apt-get install jq -y && \
    apt-get install npm -y && \
    npm install -g ajv-cli && \
    mkdir -p /var/lib/jf && \
    mkdir -p /app/lib && \
    mkdir -p /app/schema
COPY ./jf /app
COPY ./lib /app/lib
COPY ./schema /app/schema
ENTRYPOINT ["/app/jf"]
CMD []
