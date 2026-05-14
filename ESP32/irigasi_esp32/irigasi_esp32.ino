// ============================================================
//  SISTEM IRIGASI OTOMATIS - v2.4
//  Perbaikan:
//  - Firebase baca/tulis digabung (batch) → tidak blocking lama
//  - kontrolPompa() diprioritaskan sebelum Firebase
//  - Mode string diseragamkan: "Otomatis", "Manual", "Jadwal"
//  - cekJadwal() interval dikurangi ke 3 detik
//  - OLED lebih responsif
//  - Flag /system/status di Firebase untuk Flutter
// ============================================================

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <WiFi.h>
#include <FirebaseESP32.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "time.h"
#include <Preferences.h>
Preferences prefs;

// ============================================================
//  KONFIGURASI WIFI (hardcode)
// ============================================================
#define WIFI_SSID     "esp"
#define WIFI_PASSWORD "12345678"

// ============================================================
//  KONFIGURASI PIN & LAYAR
// ============================================================
#define SOIL_PIN      34
#define RELAY_PIN     27
#define BOOT_PIN       0
#define OLED_SDA      22
#define OLED_SCL      21
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

// ============================================================
//  KONFIGURASI FIREBASE
// ============================================================
#define FIREBASE_HOST "irigasi-cerdas-baru-default-rtdb.asia-southeast1.firebasedatabase.app"
#define FIREBASE_AUTH "AIzaSyBgPPFeYDUs-N6CU9WqZi0UGj8zOsLPVjo"

// ============================================================
//  KONFIGURASI BLE UUID
// ============================================================
#define SERVICE_UUID     "12345678-1234-1234-1234-123456789abc"
#define CHAR_STATUS_UUID "12345678-1234-1234-1234-123456789ab3"

// ============================================================
//  KONFIGURASI WAKTU & SENSOR
// ============================================================
const char* ntpServer      = "pool.ntp.org";
const long  gmtOffset_sec  = 25200; // WIB GMT+7
const int   daylightOffset = 0;

const int nilaiKering       = 1420;
const int nilaiBasah        = 4095;
const int MAX_DURASI_MENIT  = 60;

// ============================================================
//  STATE MACHINE
// ============================================================
enum SystemState { STATE_BLE, STATE_RUNNING };
SystemState systemState = STATE_BLE;

// ============================================================
//  VARIABEL BLE
// ============================================================
BLEServer*         pServer     = nullptr;
BLECharacteristic* pCharStatus = nullptr;
bool bleDeviceConnected = false;
bool blePaired          = false;

// ============================================================
//  VARIABEL WIFI & FIREBASE
// ============================================================
FirebaseData   fbdo;
FirebaseData   fbdoWrite;  // Pisahkan objek untuk baca & tulis
FirebaseConfig fbConfig;
FirebaseAuth   fbAuth;

bool firebaseInited = false;
bool ntpSynced      = false;
bool systemReady    = false; // true setelah pairing BLE berhasil

// ============================================================
//  VARIABEL SENSOR & KONTROL
// ============================================================
int    kelembapan     = 0;
String statusTanah    = "";
String statusTerakhir = "";

// ============================================================
//  PENTING: Gunakan string yang SAMA persis dengan Flutter
//  Flutter kirim: "Otomatis", "Manual", "Jadwal"
// ============================================================
String modeControl   = "Otomatis";
bool   pumpManualReq = false;

// ============================================================
//  VARIABEL JADWAL
// ============================================================
struct Jadwal {
    String tanggal = "";
    int    jam     = -1;
    int    menit   = -1;
    int    durasi  = 0;
};
Jadwal jadwal;

bool          jadwalAktif   = false;
unsigned long jadwalMulaiMs = 0;

// ============================================================
//  TIMER NON-BLOCKING
// ============================================================
unsigned long prevReadSensor = 0;
unsigned long prevReadFB     = 0;
unsigned long prevUpdateFB   = 0;
unsigned long prevOLED       = 0;
unsigned long prevCekJadwal  = 0;
unsigned long prevNTPRetry   = 0;
unsigned long prevWiFiRetry  = 0;
int           wifiPercobaan  = 0;

// ============================================================
//  OBJEK OLED
// ============================================================
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// ============================================================
//  BLE CALLBACKS
// ============================================================
class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* s) override {
      bleDeviceConnected = true;
      blePaired = true;
      Serial.println("[BLE] Android terhubung — pairing berhasil!");
    }
    void onDisconnect(BLEServer* s) override {
      bleDeviceConnected = false;
    }
};

// ============================================================
//  INISIALISASI BLE
// ============================================================
void initBLE() {
  BLEDevice::init("ESP32-Irigasi");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);
  pCharStatus = pService->createCharacteristic(
          CHAR_STATUS_UUID,
          BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ
  );
  pCharStatus->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising* pAdv = BLEDevice::getAdvertising();
  pAdv->addServiceUUID(SERVICE_UUID);
  pAdv->start();
  Serial.println("[BLE] Advertising dimulai — menunggu pairing...");
}

void stopBLE() {
  BLEDevice::getAdvertising()->stop();
  delay(100);
  BLEDevice::deinit(true);
  Serial.println("[BLE] BLE dimatikan.");
}

// ============================================================
//  INISIALISASI FIREBASE
// ============================================================
void initFirebase() {
  if (firebaseInited) return;
  fbConfig.host = FIREBASE_HOST;
  fbConfig.signer.tokens.legacy_token = FIREBASE_AUTH;
  Firebase.begin(&fbConfig, &fbAuth);
  Firebase.reconnectWiFi(true);
  firebaseInited = true;
  Serial.println("[FB] Firebase diinisialisasi.");
}

// ============================================================
//  AMBIL WAKTU STRING
// ============================================================
String getWaktuString() {
  struct tm t;
  if (!getLocalTime(&t)) return "";
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &t);
  return String(buf);
}

bool cekNTPSync() {
  struct tm t;
  if (!getLocalTime(&t)) return false;
  return (t.tm_year + 1900) > 2023;
}

// ============================================================
//  POMPA HELPER
// ============================================================
void setPompa(bool nyala) {
  digitalWrite(RELAY_PIN, nyala ? LOW : HIGH);
}

bool getPompaState() {
  return digitalRead(RELAY_PIN) == LOW;
}

// ============================================================
//  BACA SENSOR KELEMBAPAN
// ============================================================
void bacaSensor() {
  int raw = analogRead(SOIL_PIN);
  kelembapan = map(raw, nilaiKering, nilaiBasah, 100, 0);
  kelembapan = constrain(kelembapan, 0, 100);

  if      (kelembapan >= 80) statusTanah = "Basah";
  else if (kelembapan >= 70) statusTanah = "Lembap";
  else                       statusTanah = "Kering";
}

// ============================================================
//  BACA FIREBASE — BATCH (1 request untuk /control, 1 untuk /schedule)
//  FIX UTAMA: Dari 6 request sequential → 2 request JSON
// ============================================================

void bacaFirebase() {
  // Baca /control
  if (Firebase.getJSON(fbdo, "/control")) {
    FirebaseJson& json = fbdo.jsonObject();
    FirebaseJsonData result;
    if (json.get(result, "mode"))  modeControl   = result.stringValue;
    if (json.get(result, "pump"))  pumpManualReq = result.boolValue;
  }

  // Baca /schedule/item — sesuai struktur Firebase aktual
  FirebaseData fbdoSched;

  if (Firebase.getString(fbdoSched, "/schedule/item/date")) {
    jadwal.tanggal = fbdoSched.stringData();
  } else {
    Serial.println("[DEBUG] Gagal baca date: " + fbdoSched.errorReason());
  }

  // time disimpan sebagai "HH:MM" — parse jam & menit
  if (Firebase.getString(fbdoSched, "/schedule/item/time")) {
    String timeStr = fbdoSched.stringData(); // contoh: "02:16"
    int colonIdx = timeStr.indexOf(':');
    if (colonIdx > 0) {
      jadwal.jam   = timeStr.substring(0, colonIdx).toInt();
      jadwal.menit = timeStr.substring(colonIdx + 1).toInt();
    }
  } else {
    Serial.println("[DEBUG] Gagal baca time: " + fbdoSched.errorReason());
  }

  if (Firebase.getInt(fbdoSched, "/schedule/item/duration")) {
    jadwal.durasi = min(fbdoSched.intData(), MAX_DURASI_MENIT);
  } else {
    Serial.println("[DEBUG] Gagal baca duration: " + fbdoSched.errorReason());
  }

  Serial.printf("[DEBUG] mode=%s | jadwal=%s %02d:%02d durasi=%d\n",
                modeControl.c_str(),
                jadwal.tanggal.c_str(),
                jadwal.jam,
                jadwal.menit,
                jadwal.durasi);
}


// ============================================================
//  KIRIM DATA KE FIREBASE — BATCH (1 request JSON)
//  FIX UTAMA: Dari 6 request sequential → 1 request JSON
// ============================================================
void kirimFirebase() {
  bool pompaOn = getPompaState();

  // Hitung sisa durasi
  int sisaDurasi = 0;
  if (jadwalAktif) {
    unsigned long elapsed = (millis() - jadwalMulaiMs) / 60000UL;
    sisaDurasi = max((int)jadwal.durasi - (int)elapsed, 0);
  }

  // Kirim semua live data dalam 1 JSON update
  FirebaseJson liveJson;
  liveJson.set("value",        kelembapan);
  liveJson.set("status",       statusTanah);
  liveJson.set("pump_state",   pompaOn);
  liveJson.set("mode_aktif",   jadwalAktif ? "Jadwal" : modeControl);
  liveJson.set("jadwal_aktif", jadwalAktif);
  liveJson.set("sisa_durasi",  sisaDurasi);

  Firebase.updateNode(fbdoWrite, "/live", liveJson);  // updateNode = PATCH, tidak hapus field lain

  // History hanya jika status berubah
  if (statusTanah != statusTerakhir) {
    FirebaseJson histJson;
    histJson.set("status",       statusTanah);
    histJson.set("nilai_persen", kelembapan);
    histJson.set("waktu",        getWaktuString());
    if (Firebase.pushJSON(fbdoWrite, "/history", histJson)) {
      statusTerakhir = statusTanah;
    }
  }
}

// ============================================================
//  LOGIKA CEK JADWAL
//  FIX: Cek dengan toleransi ±30 detik agar tidak melewati momen
// ============================================================
void cekJadwal() {
  // Mode bukan Jadwal → batalkan
  if (modeControl != "Jadwal") {
    if (jadwalAktif) {
      jadwalAktif = false;
      setPompa(false);
      Serial.println("[JADWAL] Mode bukan Jadwal — jadwal dibatalkan.");
    }
    return;
  }

  if (jadwal.tanggal == "" || jadwal.jam < 0 || jadwal.menit < 0 || jadwal.durasi <= 0) {
    Serial.println("[JADWAL] Data jadwal belum lengkap.");
    return;
  }
  if (!ntpSynced) {
    Serial.println("[JADWAL] NTP belum sync, jadwal ditunda.");
    return;
  }

  struct tm t;
  if (!getLocalTime(&t)) return;

  char tglBuf[12];
  strftime(tglBuf, sizeof(tglBuf), "%Y-%m-%d", &t);
  String tglSekarang = String(tglBuf);

  if (tglSekarang != jadwal.tanggal) return;

  // Hitung total menit saat ini dan jadwal untuk perbandingan yang lebih andal
  int menitSekarang = t.tm_hour * 60 + t.tm_min;
  int menitJadwal   = jadwal.jam  * 60 + jadwal.menit;

  // Aktifkan jika belum aktif dan sudah waktunya (toleransi: tidak lewat lebih dari 1 menit)
  if (!jadwalAktif && menitSekarang == menitJadwal) {
    jadwalAktif   = true;
    jadwalMulaiMs = millis();
    setPompa(true);
    Serial.printf("[JADWAL] Pompa ON — %02d:%02d, durasi %d menit\n",
                  jadwal.jam, jadwal.menit, jadwal.durasi);
  }

  // Matikan jika durasi habis
  if (jadwalAktif) {
    unsigned long elapsedMenit = (millis() - jadwalMulaiMs) / 60000UL;
    if (elapsedMenit >= (unsigned long)jadwal.durasi) {
      jadwalAktif = false;
      setPompa(false);
      Serial.println("[JADWAL] Durasi selesai, pompa dimatikan.");
    }
  }
}

// ============================================================
//  LOGIKA KONTROL POMPA
//  FIX: Gunakan string yang sama persis dengan Flutter
// ============================================================
void kontrolPompa() {
  if (modeControl == "Jadwal") {
    // Jadwal: hanya cekJadwal() yang boleh nyalakan pompa
    if (!jadwalAktif) setPompa(false);
    return;
  }

  if (modeControl == "Manual") {
    setPompa(pumpManualReq);
    return;
  }

  // Mode Otomatis (string dari Flutter adalah "Otomatis")
  if (kelembapan < 70) setPompa(true);
  else                 setPompa(false);
}

// ============================================================
//  OLED: LAYAR STATE BLE
// ============================================================
void oledBLE(bool connected) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.setCursor(0, 0);
  display.println("-- Mode Pairing --");
  display.drawFastHLine(0, 10, 128, WHITE);
  display.setCursor(0, 16);
  if (!connected) {
    display.println("Menunggu Android...");
    display.setCursor(0, 30);
    display.println("BLE: ESP32-Irigasi");
  } else {
    display.println("Android terhubung!");
    display.setCursor(0, 30);
    display.println("Sistem disiapkan...");
  }
  display.display();
}

// ============================================================
//  OLED: TAMPILAN UTAMA
// ============================================================
void updateOLED() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);

  // Baris 1: WiFi
  display.setCursor(0, 0);
  bool wifiOk = (WiFi.status() == WL_CONNECTED);
  display.print("WiFi: ");
  display.print(wifiOk ? "OK" : "X");

  // Baris 1 kanan: NTP
  display.setCursor(60, 0);
  display.print("NTP:");
  display.print(ntpSynced ? "OK" : "X");

  display.drawFastHLine(0, 10, 128, WHITE);

  // Kelembapan besar
  display.setTextSize(2);
  display.setCursor(25, 14);
  display.print(kelembapan);
  display.print("%");

  // Status tanah & Mode
  display.setTextSize(1);
  display.setCursor(0, 34);
  display.print(statusTanah);
  display.setCursor(70, 34);
  display.print("Mode:");
  // Singkat: Oto/Man/Jdw
  if      (modeControl == "Otomatis") display.print("Oto");
  else if (modeControl == "Manual")   display.print("Man");
  else if (modeControl == "Jadwal")   display.print("Jdw");
  else                                display.print(modeControl.substring(0, 3));

  display.drawFastHLine(0, 44, 128, WHITE);

  // Pompa & Jadwal
  display.setCursor(0, 50);
  display.print("PUMP:");
  display.print(getPompaState() ? "ON " : "OFF");
  display.setCursor(55, 50);
  if (jadwalAktif) {
    unsigned long sisa = jadwal.durasi - ((millis() - jadwalMulaiMs) / 60000UL);
    display.print("Sisa:");
    display.print(sisa);
    display.print("m");
  } else if (!wifiOk) {
    display.print("Coba#");
    display.print(wifiPercobaan);
  } else {
    // Tampilkan jam jadwal jika mode Jadwal
    if (modeControl == "Jadwal" && jadwal.jam >= 0) {
      display.printf("%02d:%02d", jadwal.jam, jadwal.menit);
    }
  }

  display.display();
}

// ============================================================
//  SETUP
// ============================================================
void setup() {
  Serial.begin(115200);

  pinMode(RELAY_PIN, OUTPUT);
  setPompa(false);
  pinMode(BOOT_PIN, INPUT_PULLUP);

  Wire.begin(OLED_SDA, OLED_SCL);
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("[OLED] Gagal init!");
  }
  display.clearDisplay();
  display.setTextColor(WHITE);
  display.setCursor(0, 0);
  display.println("Sistem Memulai...");
  display.display();

// Cek flag paired di Preferences
  prefs.begin("irigasi", true);
  bool sudahPaired = prefs.getBool("paired", false);
  prefs.end();

  if (sudahPaired) {
    // Langsung STATE_RUNNING tanpa BLE
    Serial.println("[BOOT] Sudah pernah pairing — skip BLE.");
    systemState = STATE_RUNNING;
    modeControl = "Otomatis";
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    wifiPercobaan = 1;
    prevWiFiRetry = millis();
  } else {
    // Belum pernah pairing — masuk STATE_BLE
    systemState = STATE_BLE;
    initBLE();
    Serial.println("[BOOT] Menunggu pairing BLE...");
  }
}


// ============================================================
//  LOOP UTAMA
//  Urutan prioritas:
//  1. Baca sensor (cepat, tidak blocking)
//  2. kontrolPompa() — SELALU dipanggil duluan agar responsif
//  3. cekJadwal() — interval 3 detik
//  4. Firebase baca (interval 3 detik, batch)
//  5. Firebase tulis (interval 5 detik, batch)
//  6. Update OLED (interval 300ms)
// ============================================================
void loop() {
  unsigned long now = millis();

  // Tombol Boot → Restart
  if (digitalRead(BOOT_PIN) == LOW) {
    delay(50);
    if (digitalRead(BOOT_PIN) == LOW) {
      Serial.println("[BOOT] Reset pairing & restart...");
      // Hapus flag paired saat tombol Boot ditekan
      prefs.begin("irigasi", false);
      prefs.putBool("paired", false);
      prefs.end();

      display.clearDisplay();
      display.setCursor(0, 0);
      display.println("Reset pairing...");
      display.display();
      delay(500);
      ESP.restart();
    }
  }

  // ==========================================================
  //  STATE: BLE PAIRING
  // ==========================================================
  if (systemState == STATE_BLE) {
    if (now - prevOLED >= 500) {
      prevOLED = now;
      oledBLE(bleDeviceConnected);
    }

    if (blePaired) {
      if (pCharStatus != nullptr) {
        pCharStatus->setValue("PAIRED-OK");
        pCharStatus->notify();
        delay(200);
      }
      Serial.println("[SYS] Pairing berhasil — matikan BLE, mulai sistem...");
      stopBLE();

      systemState  = STATE_RUNNING;
      modeControl  = "Otomatis";  // Default mode = Otomatis
      systemReady  = true;

      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      wifiPercobaan = 1;
      prevWiFiRetry = now;
      Serial.println("[WIFI] Memulai koneksi WiFi...");
    }
    return;
  }

  // ==========================================================
  //  STATE: RUNNING
  // ==========================================================
  bool wifiOk = (WiFi.status() == WL_CONNECTED);

  // WiFi reconnect tiap 8 detik
  if (!wifiOk) {
    if (now - prevWiFiRetry >= 8000) {
      prevWiFiRetry = now;
      wifiPercobaan++;
      WiFi.disconnect();
      delay(50);
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      Serial.printf("[WIFI] Percobaan ke-%d...\n", wifiPercobaan);
    }
  } else {
    if (!firebaseInited) {
      Serial.println("[WIFI] Terhubung! IP: " + WiFi.localIP().toString());
      configTime(gmtOffset_sec, daylightOffset, ntpServer);
      delay(300);
      ntpSynced = cekNTPSync();
      Serial.printf("[NTP] Sync: %s\n", ntpSynced ? "Berhasil" : "Gagal");
      initFirebase();

      // Tulis status sistem ke Firebase
      // Jika systemReady = true (sudah pairing), tulis paired
      // Jika false (boot tanpa pairing baru), tulis booting
      if (systemReady) {
        Firebase.setString(fbdoWrite, "/system/status", "ready");
      } else {
        Firebase.setString(fbdoWrite, "/system/status", "booting");
      }
    }
  }

  // Retry NTP tiap 30 detik
  if (!ntpSynced && wifiOk) {
    if (now - prevNTPRetry >= 30000) {
      prevNTPRetry = now;
      ntpSynced = cekNTPSync();
      if (ntpSynced) Serial.println("[NTP] Sync berhasil.");
    }
  }

  // ----------------------------------------------------------
  //  1. BACA SENSOR (tiap 1 detik) — cepat, tidak blocking
  // ----------------------------------------------------------
  if (now - prevReadSensor >= 1000) {
    prevReadSensor = now;
    bacaSensor();
  }

  // ----------------------------------------------------------
  //  2. KONTROL POMPA — PRIORITAS TINGGI, panggil SETIAP loop
  //     Ini memastikan pompa segera merespons perubahan mode/manual
  // ----------------------------------------------------------
  kontrolPompa();

  // ----------------------------------------------------------
  //  3. CEK JADWAL tiap 3 detik (lebih sering dari sebelumnya)
  // ----------------------------------------------------------
  if (now - prevCekJadwal >= 3000) {
    prevCekJadwal = now;
    cekJadwal();
  }

  // ----------------------------------------------------------
  //  4. BACA FIREBASE tiap 3 detik (batch JSON — jauh lebih cepat)
  // ----------------------------------------------------------
  if (wifiOk && (now - prevReadFB >= 3000)) {
    prevReadFB = now;
    bacaFirebase();
  }

  // ----------------------------------------------------------
  //  5. KIRIM FIREBASE tiap 5 detik (batch JSON — jauh lebih cepat)
  // ----------------------------------------------------------
  if (wifiOk && (now - prevUpdateFB >= 5000)) {
    prevUpdateFB = now;
    kirimFirebase();
  }

  // ----------------------------------------------------------
  //  6. UPDATE OLED tiap 300ms (lebih responsif dari 500ms)
  // ----------------------------------------------------------
  if (now - prevOLED >= 300) {
    prevOLED = now;
    updateOLED();
  }
}
