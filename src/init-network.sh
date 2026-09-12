#!/bin/bash
# Script deteksi otomatis jaringan Wi-Fi/LAN host untuk Macvlan

# Dapatkan lokasi root project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 1. Cari default network interface yang aktif
IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

if [ -z "$IFACE" ]; then
    echo "Gagal mendeteksi interface jaringan aktif."
    exit 1
fi

# 2. Ambil IP host dan Subnet
IP_HOST=$(ip -4 addr show "$IFACE" | grep inet | awk '{print $2}' | head -n1)
SUBNET=$(ip route | grep "$IFACE" | grep -v default | awk '{print $1}' | head -n1)
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)

# 3. Hitung prefix IP (3 oktet pertama) untuk menentukan IP VPS (.150)
PREFIX=$(echo "$IP_HOST" | cut -d'.' -f1-3)
VPS_IP="${PREFIX}.150"

# 4. Tulis ke file .env di root project
cat <<EOF > "$PROJECT_ROOT/.env"
PARENT_IFACE=$IFACE
SUBNET=$SUBNET
GATEWAY=$GATEWAY
VPS_IP=$VPS_IP
EOF

echo "Jaringan terdeteksi:"
echo "- Interface: $IFACE"
echo "- Subnet: $SUBNET"
echo "- Gateway: $GATEWAY"
echo "- IP VPS (Macvlan): $VPS_IP"
echo "File .env berhasil dibuat di $PROJECT_ROOT/.env"
