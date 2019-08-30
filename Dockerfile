
From ubuntu:18.04
RUN apt-get update && \
    apt-get install jq -y && \
    mkdir -p /var/lib/jf && \
    mkdir -p /app
COPY ./jf /app
ENTRYPOINT ["/app/jf"]
CMD []
