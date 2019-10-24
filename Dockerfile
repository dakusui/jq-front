FROM ubuntu:18.04
RUN apt-get update && \
    apt-get install jq -y && \
    apt-get install npm -y && \
    apt-get install python -y && \
    apt-get install python-pip -y && \
    pip install yq && \
    npm install -g ajv-cli && \
    mkdir -p /var/lib/jq-front && \
    mkdir -p /app/lib && \
    mkdir -p /app/schema
COPY ./jq-front /app
COPY ./lib /app/lib
COPY ./schema /app/schema
ENTRYPOINT ["/app/jq-front"]
CMD []
