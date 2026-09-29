# Ubuntu 24.04 Non-KVM System Container VPS

Proyek ini menyediakan lingkungan **VPS Utuh berbasis Container Sistem Operasi (Non-KVM / OS-level Virtualization)** menggunakan Ubuntu 24.04 dan Docker / Podman Compose. Bukan sekadar simulasi sekali pakai, proyek ini dirancang sebagai VPS mandiri yang memiliki persistensi data, performa tinggi, akses jaringan lokal & luar (WAN), serta mampu menjalankan banyak service di dalamnya.

---

## Konsep & Arsitektur VPS Non-KVM

- **System Container (Systemd PID 1):** Menjalankan init systemd utuh untuk mengelola daemon sistem (SSH, Docker DinD, Nginx, Cron, dll.) layaknya VPS sejati tanpa overhead hypervisor.
- **Isolasi Resource (Cgroups v2 + LXCFS + Storage Limit):**
  - Limit CPU & RAM: **4 vCPU** (`cpus: 4.0`) dan **8 GB RAM** (`mem_limit: 8g`).
  - Limit Disk Storage: **20 GB** (`storage_opt: size: "20G"`).
  - Menggunakan **LXCFS** agar utility seperti `htop`, `free -m`, dan `nproc` membaca batas cgroup secara akurat.
- **Isolasi Storage & Persistensi Data (Storage Limit 20 GB & Direktori Lokal `./data`):**
  - **Storage Limit 20 GB (`storage_opt: size: "20G"`):** Menetapkan batasan kapasitas penyimpanan root container maksimal 20 GB.
  - **Persistent Volumes (`./data`):** Seluruh data persisten (seperti file user di `/home/ubuntu`, `/root`, data docker DinD di `/var/lib/docker`, serta direktori `/data`) disimpan langsung di folder lokal host `./data/` sehingga tetap aman dan tidak hilang meskipun container dihentikan atau dihapus.
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
1. **Opsi 1: Port Forwarding Router Fisik**
   Arahkan port router fisik Anda ke IP lokal VPS (`${VPS_IP}`).

2. **Opsi 2: Tailscale (Private Mesh VPN)**
   ```bash
   # Di dalam VPS:
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

3. **Opsi 3: Cloudflare Tunnel (`cloudflared`) — Akses Web & SSH Tanpa Port Forwarding**
   Cloudflare Tunnel memungkinkan Anda mengekspos website, API, atau bahkan akses SSH ke internet secara gratis, aman dengan SSL otomatis, dan tanpa perlu IP publik/port forwarding router.

   #### A. Pasang `cloudflared` di dalam VPS
   Masuk ke dalam VPS (`docker exec -it ubuntu24-hermes-fdab0dfb bash` atau SSH), lalu jalankan:
   ```bash
   # Unduh paket resmi deb cloudflared
   curl -L --output /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   sudo dpkg -i /tmp/cloudflared.deb && rm /tmp/cloudflared.deb
   ```

   #### B. Metode 1: Quick Tunnel (Pengujian Instan Tanpa Perlu Domain)
   Jika Anda hanya ingin mengekspos port service secara cepat:
   ```bash
   # Contoh mengekspos Nginx/Web di port 80:
   cloudflared tunnel --url http://localhost:80
   ```
   Cloudflare akan langsung memberikan URL publik gratis (misal: `https://contoh-nama-acak.trycloudflare.com`).

   #### C. Metode 2: Permanent Tunnel via Cloudflare Zero Trust (Rekomendasi untuk Domain Sendiri)
   1. Buka [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/) > **Networks** > **Tunnels** > Klik **Create a tunnel**.
   2. Pilih **Cloudflared**, beri nama tunnel (misal `vps-local`), lalu klik **Save tunnel**.
   3. Pada bagian *Install and run a connector*, pilih lingkungan **Debian 64-bit**.
   4. Salin perintah instalasi service yang berisi token unik Anda, lalu jalankan di terminal VPS:
      ```bash
      sudo cloudflared service install <TOKEN_DARI_DASHBOARD_ANDA>
      ```
   5. Cloudflared akan otomatis berjalan di background sebagai service systemd:
      ```bash
      systemctl status cloudflared
      ```
   6. Di dashboard Cloudflare, buka tab **Public Hostname** dan tambahkan route:
      - **Untuk Web/Aplikasi:**
        - Subdomain: `app` (domain: `domainanda.com`)
        - Service: `HTTP` `localhost:80` (atau port web Anda)
      - **Untuk Akses SSH Jarak Jauh:**
        - Subdomain: `ssh` (domain: `domainanda.com`)
        - Service: `SSH` `localhost:22`

   #### D. Cara Akses SSH VPS via Cloudflare Tunnel dari Laptop Luar
   Di laptop host/klien yang ingin mengakses VPS dari luar jaringan:
   1. Pasang `cloudflared` di laptop klien Anda.
   2. Tambahkan konfigurasi di `~/.ssh/config` laptop Anda:
      ```text
      Host vps-remote
          HostName ssh.domainanda.com
          User root
          ProxyCommand cloudflared access ssh --hostname %h
      ```
   3. Cukup jalankan perintah berikut dari mana saja di seluruh dunia:
      ```bash
      ssh vps-remote
      ```

---

## 5. Manajemen Layanan di dalam VPS

Masuk ke dalam VPS:
```bash
# Login sebagai root (password: admin0123!)
ssh root@<VPS_IP>

# Atau login sebagai user ubuntu
ssh ubuntu@<VPS_IP>
```
atau via exec (otomatis masuk sebagai root):
```bash
docker exec -it ubuntu24-hermes-fdab0dfb bash
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


