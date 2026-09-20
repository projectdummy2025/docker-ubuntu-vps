# Ubuntu 24.04 Non-KVM System Container VPS

Proyek ini menyediakan lingkungan **VPS Utuh berbasis Container Sistem Operasi (Non-KVM / OS-level Virtualization)** menggunakan Ubuntu 24.04 dan Docker / Podman Compose. Bukan sekadar simulasi sekali pakai, proyek ini dirancang sebagai VPS mandiri yang memiliki persistensi data, performa tinggi, akses jaringan lokal & luar (WAN), serta mampu menjalankan banyak service di dalamnya.

---

## Konsep & Arsitektur VPS Non-KVM

- **System Container (Systemd PID 1):** Menjalankan init systemd utuh untuk mengelola daemon sistem (SSH, Docker DinD, Nginx, Cron, dll.) layaknya VPS sejati tanpa overhead hypervisor.
- **Isolasi Resource (Cgroups v2 + LXCFS + Storage Limit):**
  - Limit CPU & RAM: **4 vCPU** (`cpus: 4.0`) dan **8 GB RAM** (`mem_limit: 8g`).
  - Limit Disk Storage: **20 GB** (`storage_opt: size: "20G"`).
  - Menggunakan **LXCFS** agar utility seperti `htop`, `free -m`, dan `nproc` membaca batas cgroup secara akurat.
- **Isolasi Storage & Single Root Volume (`vps-system-root:/`):**
  - **Single Root Disk Volume (`vps-system-root`):** Di-mount langsung pada root `/`. Seluruh aktivitas sistem (`apt install`, editan `/etc`, `/var`, `/opt`, `/root`, `/home`, database, cron, hingga docker containers) tersimpan otomatis dalam 1 disk volume persisten layaknya disk fisik/KVM VPS sejati.
  - **Tmpfs Volatile:** `/run`, `/run/lock`, dan `/tmp` menggunakan `tmpfs` agar RAM/runtime clean saat reboot container.
- **Jaringan Lokal (LAN) & Port Bebas:**
  - Menggunakan driver **Macvlan** dengan IP LAN mandiri (`${VPS_IP}`).
  - **Seluruh port (1-65535)** terbuka langsung di IP VPS. Anda dapat memasang database, API, atau server web di port mana saja tanpa perlu mengubah `docker-compose.yml`.
  - *Catatan:* Isolasi kernel Macvlan membuat host dan guest tidak bisa saling ping/akses langsung via IP Macvlan (dibiarkan secara by-design). Host dapat mengakses via bridge localhost port 2222/8080.
- **Akses Jaringan Luar (Internet & WAN) & Stabilitas Unduhan:**
  - **DNS Mandiri:** Menggunakan DNS publik (`1.1.1.1`, `8.8.8.8`) langsung di container, mengatasi kendala DNS timeout akibat resolver host `127.0.0.53`.
  - **TCP MSS Clamping:** Layanan otomatis iptables `TCPMSS --clamp-mss-to-pmtu` mencegah transfer data/unduhan macet akibat MTU mismatch di Macvlan.
  - **IPv4 Optimized:** Menghindari IPv6 connection stall saat `apt-get` atau `curl`.
  - **Dukungan VPN/Tunneling:** Device `/dev/net/tun` terpasang, memungkinkan VPS menjalankan Tailscale, WireGuard, atau Cloudflare Tunnel untuk akses remote dari internet/WAN tanpa perlu port-forwarding router fisik.

---

## 1. Prasyarat Host: Pasang LXCFS

Agar container dapat membaca limit CPU dan RAM sesuai batas yang ditentukan:

**Fedora:**
```bash
sudo dnf install -y lxcfs
sudo systemctl enable --now lxcfs
```

**Ubuntu / Debian:**
```bash
sudo apt update && sudo apt install -y lxcfs
sudo systemctl enable --now lxcfs
```

---

## 2. Deteksi Jaringan Router & Buat `.env`

Jalankan script otomatisasi setiap kali terhubung ke router / Wi-Fi baru:

```bash
bash src/init-network.sh
```

Script ini akan mengisi variabel `PARENT_IFACE`, `SUBNET`, `GATEWAY`, dan `VPS_IP` di `.env`.

---

## 3. Jalankan VPS

```bash
docker compose up -d --build
```
Atau menggunakan Podman:
```bash
podman compose up -d --build
```

---

## 4. Mengakses VPS & Service

### A. Dari Jaringan Lokal (LAN / Perangkat Lain)
Gunakan IP Macvlan VPS (`${VPS_IP}`):
- **SSH:** `ssh ubuntu@<VPS_IP>` (port default: 22)
- **Web:** `http://<VPS_IP>` (port 80)
- **Service Lain:** Buka service apa pun di dalam VPS (misal Node.js di port 3000, PostgreSQL di port 5432), langsung akses via `<VPS_IP>:<PORT>`.

### B. Dari Laptop Host
- **SSH:** `ssh ubuntu@localhost -p 2222`
- **HTTP:** `http://localhost:8080`

### C. Dari Jaringan Luar (Internet / WAN)
1. **Opsi 1: Port Forwarding Router**
   Arahkan port router fisik Anda ke IP lokal VPS (`${VPS_IP}`).
2. **Opsi 2: Tailscale / WireGuard / Cloudflare Tunnel (Direkomendasikan)**
   Jalankan Tailscale atau Cloudflare Tunnel langsung di dalam VPS:
   ```bash
   # Di dalam VPS:
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```
   VPS akan langsung memiliki IP publik/privat global yang bisa diakses dari mana saja.

---

## 5. Manajemen Layanan di dalam VPS

Masuk ke dalam VPS:
```bash
ssh ubuntu@<VPS_IP>
```
atau via exec:
```bash
docker exec -it ubuntu-vps bash
```

Kelola service internal:
```bash
sudo systemctl status nginx
sudo systemctl status docker
```

Menjalankan Docker di dalam VPS (DinD):
```bash
docker run -d -p 8080:80 nginx:alpine
```
*(Data image dan container tersimpan secara permanen di volume `vps-docker-data`)*.

---

## 6. Menghentikan VPS

- Menghentikan container tanpa menghapus data persisten:
  ```bash
  docker compose stop
  ```
- Menghapus container (data volume tetap aman):
  ```bash
  docker compose down
  ```

---

## 7. Troubleshooting

### Warning : Remote Host Identification Has Changed (SSH Host Key Changed)
Jika container di-rebuild, SSH server menghasilkan host key baru. Jalankan perintah ini di laptop host untuk menghapus entri key lama dari `known_hosts`:

```bash
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[localhost]:2222"
```

Atau login langsung tanpa verifikasi `known_hosts`:

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@localhost -p 2222
```


