FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Paksa APT memakai IPv4 untuk mencegah timeout koneksi
RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

# Pasang paket dasar server, MOTD, monitoring, VPN/tunneling, dan utilitas standar VPS
RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd \
    systemd-sysv \
    openssh-server \
    nginx \
    docker.io \
    docker-compose-v2 \
    docker-buildx \
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
    wireguard-tools \
    dnsutils \
    iputils-ping \
    traceroute \
    socat \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Pangkas unit service yang tidak diperlukan di dalam container
RUN rm -f /lib/systemd/system/multi-user.target.wants/getty.target \
    && rm -f /lib/systemd/system/systemd-resolved.service

# Konfigurasi Docker daemon untuk DinD (optimasi MTU 1350, DNS publik, dan nonaktifkan containerd-snapshotter)
RUN mkdir -p /etc/docker && \
    echo '{"features": {"containerd-snapshotter": false}, "mtu": 1350, "dns": ["1.1.1.1", "8.8.8.8"]}' > /etc/docker/daemon.json

# Salin script inisialisasi boot
COPY src/vps-init.sh /usr/local/bin/vps-init.sh
RUN chmod +x /usr/local/bin/vps-init.sh

# Pasang service systemd untuk inisialisasi boot
RUN printf '[Unit]\n\
Description=VPS Network & Home Init\n\
After=network.target\n\
\n\
[Service]\n\
Type=oneshot\n\
ExecStart=/usr/local/bin/vps-init.sh\n\
RemainAfterExit=yes\n\
\n\
[Install]\n\
WantedBy=multi-user.target\n' > /etc/systemd/system/vps-network-tune.service

# Aktifkan service agar otomatis jalan saat boot init
RUN systemctl enable ssh && \
    systemctl enable nginx && \
    systemctl enable cron && \
    systemctl enable docker && \
    systemctl enable vps-network-tune

# Konfigurasi user admin VPS dan user root (mendukung login langsung root/ubuntu)
RUN (id -u ubuntu >/dev/null 2>&1 || useradd -m -s /bin/bash ubuntu) && \
    echo "ubuntu:admin0123!" | chpasswd && \
    echo "root:admin0123!" | chpasswd && \
    usermod -aG sudo,docker ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
