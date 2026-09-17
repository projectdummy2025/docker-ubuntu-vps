FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Pasang paket dasar server, MOTD, monitoring, dan utilitas standar VPS
RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd \
    systemd-sysv \
    openssh-server \
    nginx \
    docker.io \
    docker-compose-v2 \
    iptables \
    git \
    sudo \
    curl \
    wget \
    iproute2 \
    procps \
    ca-certificates \
    net-tools \
    htop \
    nano \
    vim \
    cron \
    rsync \
    ufw \
    landscape-common \
    update-motd \
    locales \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Pangkas unit service yang tidak diperlukan di dalam container
RUN rm -f /lib/systemd/system/multi-user.target.wants/getty.target \
    && rm -f /lib/systemd/system/systemd-resolved.service

# Konfigurasi Docker daemon untuk DinD (nonaktifkan containerd-snapshotter overlayfs conflict)
RUN mkdir -p /etc/docker && \
    echo '{"features": {"containerd-snapshotter": false}}' > /etc/docker/daemon.json

# Aktifkan service agar otomatis jalan saat boot init
RUN systemctl enable ssh && \
    systemctl enable nginx && \
    systemctl enable cron && \
    systemctl enable docker

# Konfigurasi user admin VPS dengan akses sudo tanpa password
RUN (id -u ubuntu >/dev/null 2>&1 || useradd -m -s /bin/bash ubuntu) && \
    echo "ubuntu:admin0123!" | chpasswd && \
    usermod -aG sudo,docker ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
