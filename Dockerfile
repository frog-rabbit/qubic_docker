FROM ghcr.io/icyblob/vbox-with-extpack:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 python3-pip unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /qubic

# Copy in entrypoint to create/launch VM
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
