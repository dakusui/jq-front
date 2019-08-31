FROM ubuntu:18.04
RUN apt-get update && \
    apt-get install jq -y && \
    apt-get install npm -y && \
    npm install -g ajv-cli && \
    mkdir -p /var/lib/jf && \
    mkdir -p /app
COPY ./jf /app
ENTRYPOINT ["/app/jf"]
CMD []
