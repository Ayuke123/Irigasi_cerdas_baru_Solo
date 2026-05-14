# Firmware ESP32 - Sistem Irigasi Cerdas (v2.4)

Folder ini berisi kode program untuk modul ESP32 yang berfungsi sebagai otak dari sistem irigasi otomatis.

## 📋 Fitur Utama
- **Multi-Mode Control**: Mendukung mode `Otomatis` (sensor), `Manual` (via App), dan `Jadwal` (NTP & Firebase).
- **Hybrid Connection**: Mendukung sinkronisasi data via WiFi (Firebase) dan pairing awal via Bluetooth (BLE).
- **OLED Interface**: Menampilkan status kelembapan, koneksi WiFi, sinkronisasi waktu (NTP), dan status pompa secara real-time.
- **Optimized Firebase**: Menggunakan teknik *batch read/write* untuk meminimalkan blocking dan menghemat data.
- **Persistent Pairing**: Status pairing Bluetooth disimpan di memori internal (Preferences).

## 🛠️ Konfigurasi Pinout
| Komponen | Pin ESP32 | Keterangan |
| :--- | :--- | :--- |
| **Sensor Kelembapan** | GPIO 34 | Input Analog |
| **Relay Pompa** | GPIO 27 | Output (Active LOW) |
| **OLED SDA** | GPIO 22 | I2C Data |
| **OLED SCL** | GPIO 21 | I2C Clock |
| **Tombol BOOT** | GPIO 0 | Tahan untuk Reset Pairing |

## 📚 Library yang Dibutuhkan
Pastikan library berikut sudah terinstal di Arduino IDE:
1. `Firebase ESP32 Client` (oleh Mobizt)
2. `Adafruit SSD1306` & `Adafruit GFX Library`
3. `Preferences` (Built-in)
4. `BLE` & `WiFi` (Built-in)

## 🚀 Cara Penggunaan
1. Buka `irigasi_esp32/irigasi_esp32.ino` menggunakan Arduino IDE.
2. Sesuaikan kredensial berikut di dalam kode:
   - `WIFI_SSID` & `WIFI_PASSWORD`
   - `FIREBASE_HOST`
   - `FIREBASE_AUTH` (Database Secret/Token)
3. Upload kode ke ESP32.
4. **Pairing Pertama**: Saat pertama kali dinyalakan, ESP32 akan masuk ke mode pairing Bluetooth. Gunakan aplikasi Flutter untuk menghubungkan.
5. **Reset Pairing**: Jika ingin mengganti perangkat atau reset, tekan dan tahan tombol **BOOT** pada ESP32 saat alat menyala.

## 📁 Struktur Data Firebase (RTDB)
Firmware ini berkomunikasi melalui path berikut:
- `/live`: Data sensor dan status pompa aktual.
- `/control`: Perintah mode dan manual dari aplikasi.
- `/schedule`: Pengaturan jadwal penyiraman.
- `/system/status`: Flag kesiapan sistem (`booting`/`ready`).
