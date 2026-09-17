# DevOps Experiment - Simulasi VPS Ubuntu 24.04

Proyek ini merupakan eksperimen **DevOps & Infrastructure as Code (IaC)** untuk mensimulasikan lingkungan **VPS ringan atau OCI System Container** berbasis Ubuntu 24.04 menggunakan Docker atau Podman Compose.

Proyek ini menggunakan virtualisasi tingkat sistem operasi (OS-level Virtualization), bukan Virtual Machine berbasis Hypervisor (seperti KVM, Proxmox, atau VMware).

---

## Konsep & Arsitektur

- **System Container :** Menggunakan `systemd` sebagai PID 1 untuk mengelola service (SSH, Nginx) layaknya VPS sejati tanpa beban overhead VM.
- **Isolasi Resource (Cgroups v2 + LXCFS) :** Dibatasi pada **4 vCPU** (`cpus: 4.0`) dan **8 GB RAM** (`mem_limit: 8g`).
  - Menggunakan **LXCFS** agar perintah `free -h`, `top`, dan `nproc` di dalam container secara akurat membaca batasan cgroup (8 GB RAM & 4 vCPU), bukan kapasitas host.
- **Hybrid Dual-Network :**
  1. **Macvlan Network :** Memberikan IP independen di jaringan LAN/Wi-Fi router untuk akses dari perangkat luar (IP laptop host tidak diekspos).
  2. **Loopback Bridge :** Mengunci port local binding (`127.0.0.1`) agar laptop host dapat mengakses VPS via `localhost` secara aman dan terisolasi.
- **Automated Network Discovery :** Script pembantu otomatis mendeteksi interface aktif, subnet, dan gateway router tempat laptop terhubung.

---

## 1. Prasyarat Host: Pasang LXCFS

Agar container dapat membaca limit CPU dan RAM sesuai spesifikasi VPS yang ditentukan:

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

Jalankan script otomatisasi setiap kali Anda terhubung ke router / Wi-Fi baru :

```bash
bash src/init-network.sh
```

Script ini akan membuat file `.env` yang terisi variabel `PARENT_IFACE`, `SUBNET`, `GATEWAY`, dan `VPS_IP` secara otomatis.

---

## 3. Jalankan Container

Docker Compose :
```bash
docker compose up -d --build
```

Podman Compose :
```bash
podman compose up -d --build
```

---

## 4. Pengujian dan Akses Layanan

### A. Dari Laptop Host (Localhost)
- **HTTP (Nginx) :**
  ```bash
  curl http://localhost:8080
  ```

- **SSH (User: ubuntu, Password: admin0123!) :**
  ```bash
  ssh ubuntu@localhost -p 2222
  ```

### B. Dari Perangkat Lain di LAN / Wi-Fi
- Gunakan IP VPS yang dihasilkan oleh `init-network.sh`:
  - **HTTP:** `http://<VPS_IP>` (contoh : `http://192.168.1.150`)
  - **SSH:** `ssh ubuntu@<VPS_IP>` (port 22)

---

## 5. Manajemen Container

- **Cek Status :**
  ```bash
  docker compose ps
  ```

- **Kelola Service (di dalam container) :**
  ```bash
  sudo systemctl status nginx
  sudo systemctl restart nginx
  ```

- **Menghentikan Container:**
  ```bash
  docker compose down
  ```

---

## 6. Troubleshooting

### Warning : Remote Host Identification Has Changed (SSH Host Key Changed)
Jika container di-rebuild atau di-restart, SSH server di dalam container akan menghasilkan host key baru. Jalankan perintah ini di laptop host untuk menghapus entri key lama dari `known_hosts` :

```bash
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "[localhost]:2222"
```

Atau gunakan opsi SSH tanpa pengecekan ketat host key:

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@localhost -p 2222
```
