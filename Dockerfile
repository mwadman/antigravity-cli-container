FROM debian:bookworm-slim

ARG ANTIGRAVITY_VERSION='latest'

# Disable updates in container
ENV AGY_CLI_DISABLE_AUTO_UPDATE=true
# Set paths
ENV HOME=/root
ENV GIT_CONFIG_GLOBAL=/root/.gitconfig
# Default TERM for better out-of-the-box experience
ENV COLORTERM=truecolor

# Install agent dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dnsutils \
    file \
    git \
    gnupg \
    jq \
    less \
    lsof \
    make \
    openssh-client \
    python3 \
    ripgrep \
    socat \
    unzip \
    vim \
    xdg-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI and Compose plugin (Docker-out-of-Docker support)
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    docker-ce-cli \
    docker-compose-plugin \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create directories (app for code, .gemini for agent configuration)
RUN mkdir -p /app /root/.gemini/antigravity-cli /root/.ssh && \
    chmod 700 /root/.ssh

# Support SSH in rootless environments
RUN echo "Include /root/.ssh/config" >> /etc/ssh/ssh_config && \
    echo "IdentityFile /root/.ssh/id_rsa" >> /etc/ssh/ssh_config && \
    echo "IdentityFile /root/.ssh/id_ed25519" >> /etc/ssh/ssh_config && \
    echo "IdentityFile /root/.ssh/id_ecdsa" >> /etc/ssh/ssh_config && \
    echo "IdentityFile /root/.ssh/id_dsa" >> /etc/ssh/ssh_config && \
    echo "UserKnownHostsFile /root/.ssh/known_hosts" >> /etc/ssh/ssh_config && \
    echo "StrictHostKeyChecking accept-new" >> /etc/ssh/ssh_config

# Install Antigravity CLI
COPY install-agy.sh /tmp/install-agy.sh
RUN chmod +x /tmp/install-agy.sh && \
    /tmp/install-agy.sh -v "${ANTIGRAVITY_VERSION}" -d /usr/local/bin && \
    rm /tmp/install-agy.sh

# Enter code directory and run agent by default
WORKDIR /app
ENTRYPOINT ["agy"]
