#!/bin/bash
# Script deteksi otomatis & generator file .env untuk Macvlan VPS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# 1. Deteksi interface default yang aktif
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

if [ -z "$IFACE" ]; then
    echo "Error: Gagal mendeteksi interface jaringan aktif. Pastikan laptop terhubung ke Wi-Fi / LAN."
    exit 1
fi

# 2. Ambil statistik IP, Subnet, dan Gateway
IP_HOST=$(ip -4 addr show "$IFACE" | grep inet | awk '{print $2}' | head -n1)
SUBNET=$(ip route | grep "$IFACE" | grep -v default | awk '{print $1}' | head -n1)
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)

# 3. Alokasikan IP VPS (.150) berdasarkan subnet router saat ini
PREFIX=$(echo "$IP_HOST" | cut -d'.' -f1-3)
VPS_IP="${PREFIX}.150"

# 4. Simpan konfigurasi ke file .env di root proyek
cat <<EOF > "$ENV_FILE"
# Konfigurasi Jaringan Dinamis (Otomatis Dihasilkan oleh init-network.sh)
PARENT_IFACE=$IFACE
SUBNET=$SUBNET
GATEWAY=$GATEWAY
VPS_IP=$VPS_IP
EOF

echo " Interface  : $IFACE"
echo " Subnet     : $SUBNET"
echo " Gateway    : $GATEWAY"
echo " IP VPS LAN : $VPS_IP"
