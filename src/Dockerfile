FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TERM=xterm-256color
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Pasang systemd, ssh, nginx, dan utilitas dasar tanpa dependensi berlebih
RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd \
    systemd-sysv \
    openssh-server \
    nginx \
    sudo \
    curl \
    iproute2 \
    procps \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Pangkas unit service yang tidak diperlukan di dalam container
RUN rm -f /lib/systemd/system/multi-user.target.wants/getty.target \
    && rm -f /lib/systemd/system/systemd-resolved.service

# Aktifkan service agar otomatis jalan saat boot init
RUN systemctl enable ssh && \
    systemctl enable nginx

# Konfigurasi user admin VPS dengan akses sudo tanpa password
RUN (id -u ubuntu >/dev/null 2>&1 || useradd -m -s /bin/bash ubuntu) && \
    echo "ubuntu:admin0123!" | chpasswd && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
