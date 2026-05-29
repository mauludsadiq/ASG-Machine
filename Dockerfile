FROM --platform=linux/amd64 ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    python3 \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install fardrun (requires GLIBC 2.39, provided by ubuntu:24.04)
RUN curl -fsSL https://github.com/mauludsadiq/FARD/releases/download/v1.6.1/fard-linux-x86_64.tar.gz \
    -o /tmp/fard.tar.gz && \
    tar xzf /tmp/fard.tar.gz -C /tmp && \
    cp /tmp/fard-linux-x86_64/fardrun /usr/local/bin/fardrun && \
    chmod +x /usr/local/bin/fardrun && \
    rm -rf /tmp/fard* && \
    fardrun --version

WORKDIR /app
COPY . .

RUN mkdir -p data/server_audit data/server_auth data/server out

EXPOSE 7779

CMD ["fardrun", "run", "--program", "server_audited.fard", "--out", "out/server_audited"]
