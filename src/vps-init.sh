#!/bin/bash
set -e

# 1. Normalisasi MTU interface ke 1500 (mencegah MTU jumbo 65520 dari rootless runtime yang memicu packet drop)
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^eth|^ens|^enp'); do
    ip link set "$iface" mtu 1500 2>/dev/null || true
done

# 2. Prioritaskan routing internet keluar lewat interface bridge (eth1) agar stabil dan bebas dari drop Macvlan Wi-Fi
BRIDGE_GW=$(ip route | grep "dev eth1" | awk '{print $3}' | head -n1)
if [ -n "$BRIDGE_GW" ]; then
    ip route replace default via "$BRIDGE_GW" dev eth1 metric 50 2>/dev/null || true
fi

# 3. TCP MSS Clamping (mencegah koneksi unduhan stall/drop di Macvlan & Docker DinD)
iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

iptables -t mangle -C POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# 4. Inisialisasi file skeleton jika bind mount ./data/home atau ./data/root di host kosong
if [ ! -f /home/ubuntu/.bashrc ]; then
    cp -rT /etc/skel /home/ubuntu
    chown -R ubuntu:ubuntu /home/ubuntu
fi

if [ ! -f /root/.bashrc ]; then
    cp -rT /etc/skel /root
    # Root default prompt: polos tanpa warna (standar VPS)
    sed -i 's/xterm-color|\*-256color) color_prompt=yes/#xterm-color|\*-256color) color_prompt=yes/' /root/.bashrc
fi

