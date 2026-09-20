#!/bin/bash
set -e

# 1. TCP MSS Clamping (mencegah koneksi unduhan stall/drop di Macvlan)
iptables -C POSTROUTING -t mangle -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# 2. Inisialisasi file skeleton jika bind mount ./data/home di host kosong
if [ ! -f /home/ubuntu/.bashrc ]; then
    cp -rT /etc/skel /home/ubuntu
    chown -R ubuntu:ubuntu /home/ubuntu
fi
