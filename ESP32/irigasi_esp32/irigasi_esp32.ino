// ============================================================
//  SISTEM IRIGASI OTOMATIS - v2.5
//  Perbaikan:
//  - Firebase baca/tulis digabung (batch) → tidak blocking lama
//  - kontrolPompa() diprioritaskan sebelum Firebase
//  - Mode string diseragamkan: "Otomatis", "Manual", "Jadwal"
//  - cekJadwal() interval dikurangi ke 3 detik
//  - OLED redesign dengan bitmap icons
//  - Flag /system/status di Firebase untuk Flutter
//  - Offline → paksa mode Otomatis
//  - lastOnline dikirim ke Firebase untuk deteksi offline di Flutter
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
//  BITMAP ICONS 16x16
// ============================================================
const unsigned char wifi_icon [] PROGMEM = {
        0x00, 0x00,
        0x03, 0xC0,
        0x0F, 0xF0,
        0x1C, 0x38,
        0x30, 0x0C,
        0x03, 0xC0,
        0x07, 0xE0,
        0x0C, 0x30,
        0x01, 0x80,
        0x03, 0xC0,
        0x06, 0x60,
        0x00, 0x00,
        0x01, 0x80,
        0x01, 0x80,
        0x00, 0x00,
        0x00, 0x00
};

const unsigned char clock_icon [] PROGMEM = {
        0x03, 0xC0,
        0x0F, 0xF0,
        0x1C, 0x38,
        0x30, 0x0C,
        0x60, 0x06,
        0x66, 0x06,
        0x63, 0x06,
        0x60, 0x06,
        0x60, 0x06,
        0x70, 0x0E,
        0x38, 0x1C,
        0x1C, 0x38,
        0x0F, 0xF0,
        0x03, 0xC0,
        0x00, 0x00,
        0x00, 0x00
};

const unsigned char water_on[] PROGMEM = {
        0x00, 0x00,
        0x01, 0x80,
        0x03, 0xC0,
        0x07, 0xE0,
        0x0F, 0xF0,
        0x1F, 0xF8,
        0x3F, 0xFC,
        0x3F, 0xFC,
        0x7F, 0xFE,
        0x7F, 0xFE,
        0x7F, 0xFE,
        0x3F, 0xFC,
        0x3F, 0xFC,
        0x1F, 0xF8,
        0x0F, 0xF0,
        0x03, 0xC0
};

const unsigned char water_off[] PROGMEM = {
        0x00, 0x00,
        0x01, 0x80,
        0x03, 0xC0,
        0x07, 0xE0,
        0x0C, 0x30,
        0x18, 0x18,
        0x30, 0x0C,
        0x30, 0x0C,
        0x60, 0x06,
        0x60, 0x06,
        0x60, 0x06,
        0x30, 0x0C,
        0x30, 0x0C,
        0x18, 0x18,
        0x0F, 0xF0,
        0x03, 0xC0
};

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
FirebaseData   fbdoWrite;
FirebaseConfig fbConfig;
FirebaseAuth   fbAuth;

bool firebaseInited = false;
bool ntpSynced      = false;
bool systemReady    = false;

// ============================================================
//  VARIABEL SENSOR & KONTROL
// ============================================================
int    kelembapan     = 0;
String statusTanah    = "";
String statusTerakhir = "";

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
unsigned long prevBlink      = 0;
int           wifiPercobaan  = 0;
bool          blinkState     = false;

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
//  BACA FIREBASE — BATCH
// ============================================================
void bacaFirebase() {
  // Baca /control
  if (Firebase.getJSON(fbdo, "/control")) {
    FirebaseJson& json = fbdo.jsonObject();
    FirebaseJsonData result;
    if (json.get(result, "mode"))  modeControl   = result.stringValue;
    if (json.get(result, "pump"))  pumpManualReq = result.boolValue;
  }

  // Baca /schedule/item per-field
  FirebaseData fbdoSched;

  if (Firebase.getString(fbdoSched, "/schedule/item/date")) {
    jadwal.tanggal = fbdoSched.stringData();
  } else {
    Serial.println("[DEBUG] Gagal baca date: " + fbdoSched.errorReason());
  }

  if (Firebase.getString(fbdoSched, "/schedule/item/time")) {
    String timeStr = fbdoSched.stringData();
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
//  KIRIM DATA KE FIREBASE — BATCH
// ============================================================
void kirimFirebase() {
  bool pompaOn = getPompaState();

  // Hitung sisa durasi dalam detik
  long sisaDetik = 0;
  if (jadwalAktif) {
    unsigned long elapsedDetik = (millis() - jadwalMulaiMs) / 1000UL;
    unsigned long totalDetik   = (unsigned long)jadwal.durasi * 60UL;
    sisaDetik = (long)totalDetik - (long)elapsedDetik;
    if (sisaDetik < 0) sisaDetik = 0;
  }

  // Kirim semua live data dalam 1 JSON update
  FirebaseJson liveJson;
  liveJson.set("value",        kelembapan);
  liveJson.set("status",       statusTanah);
  liveJson.set("pump_state",   pompaOn);
  liveJson.set("mode_aktif",   jadwalAktif ? "Jadwal" : modeControl);
  liveJson.set("jadwal_aktif", jadwalAktif);
  liveJson.set("sisa_durasi",  (int)sisaDetik);

  // Tambah lastOnline dalam epoch milliseconds
  struct tm timeinfo;
  if (getLocalTime(&timeinfo)) {
    time_t epoch = mktime(&timeinfo);
    liveJson.set("lastOnline", (long long)epoch * 1000LL);
  }

  Firebase.updateNode(fbdoWrite, "/live", liveJson);

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
// ============================================================
void cekJadwal() {
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

  int menitSekarang = t.tm_hour * 60 + t.tm_min;
  int menitJadwal   = jadwal.jam  * 60 + jadwal.menit;

  if (!jadwalAktif && menitSekarang == menitJadwal) {
    jadwalAktif   = true;
    jadwalMulaiMs = millis();
    setPompa(true);
    Serial.printf("[JADWAL] Pompa ON — %02d:%02d, durasi %d menit\n",
                  jadwal.jam, jadwal.menit, jadwal.durasi);
  }

  // Matikan jika durasi habis (dalam detik)
  if (jadwalAktif) {
    unsigned long elapsedDetik = (millis() - jadwalMulaiMs) / 1000UL;
    if (elapsedDetik >= (unsigned long)(jadwal.durasi * 60UL)) {
      jadwalAktif = false;
      setPompa(false);
      Serial.println("[JADWAL] Durasi selesai, pompa dimatikan.");
    }
  }
}

// ============================================================
//  LOGIKA KONTROL POMPA
// ============================================================
void kontrolPompa() {
  bool wifiOk = (WiFi.status() == WL_CONNECTED);

  // Jika offline, paksa mode Otomatis
  if (!wifiOk) {
    if (kelembapan < 70) setPompa(true);
    else                 setPompa(false);
    return;
  }

  if (modeControl == "Jadwal") {
    if (!jadwalAktif) setPompa(false);
    return;
  }

  if (modeControl == "Manual") {
    setPompa(pumpManualReq);
    return;
  }

  // Mode Otomatis
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
//
//  LAYOUT 128x64:
//  ┌────────────────────────────────┐
//  │ [wifi] OK   [clock] HH:MM     │  Y: 0–16
//  ├────────────────────────────────┤
//  │      75%       Lembap         │  Y: 18–38
//  ├────────────────────────────────┤
//  │ Mode: Otomatis                │  Y: 40–50
//  ├────────────────────────────────┤
//  │ [drop] Pompa ON / Sisa: Xdtk  │  Y: 53–64
//  └────────────────────────────────┘
// ============================================================
void updateOLED() {
  unsigned long now = millis();
  bool wifiOk = (WiFi.status() == WL_CONNECTED);

  // Efek kedip pompa setiap 500ms
  if (now - prevBlink >= 500) {
    prevBlink  = now;
    blinkState = !blinkState;
  }

  display.clearDisplay();
  display.setTextColor(WHITE);

  // ----------------------------------------------------------
  //  BARIS 1 — Ikon WiFi + status | Ikon Clock + jam
  // ----------------------------------------------------------
  display.drawBitmap(0, 0, wifi_icon, 16, 16, WHITE);
  display.setTextSize(1);
  display.setCursor(18, 4);
  display.print(wifiOk ? "OK" : "X");

  display.drawBitmap(50, 0, clock_icon, 16, 16, WHITE);
  display.setCursor(68, 4);
  if (ntpSynced) {
    struct tm t;
    if (getLocalTime(&t)) {
      char jamBuf[6];
      strftime(jamBuf, sizeof(jamBuf), "%H:%M", &t);
      display.print(jamBuf);
    } else {
      display.print("--:--");
    }
  } else {
    display.print("--:--");
  }

  display.drawFastHLine(0, 17, 128, WHITE);

  // ----------------------------------------------------------
  //  BARIS 2 — Nilai kelembapan besar + status tanah
  // ----------------------------------------------------------
  display.setTextSize(2);
  display.setCursor(10, 20);
  display.print(kelembapan);
  display.print("%");

  display.setTextSize(1);
  display.setCursor(75, 24);
  display.print(statusTanah);

  display.drawFastHLine(0, 39, 128, WHITE);

  // ----------------------------------------------------------
  //  BARIS 3 — Mode aktif
  // ----------------------------------------------------------
  display.setTextSize(1);
  display.setCursor(0, 41);
  display.print("Mode: ");
  if (!wifiOk) {
    display.print("Otomatis*");
  } else if (modeControl == "Otomatis") {
    display.print("Otomatis");
  } else if (modeControl == "Manual") {
    display.print("Manual");
  } else if (modeControl == "Jadwal") {
    display.print("Jadwal");
  }

  display.drawFastHLine(0, 52, 128, WHITE);

  // ----------------------------------------------------------
  //  BARIS 4 — Ikon pompa + status / sisa waktu
  // ----------------------------------------------------------
  bool pompaOn = getPompaState();

  // Ikon berkedip saat pompa ON, outline saat OFF
  if (pompaOn) {
    display.drawBitmap(0, 53, blinkState ? water_on : water_off, 16, 16, WHITE);
  } else {
    display.drawBitmap(0, 53, water_off, 16, 16, WHITE);
  }

  display.setCursor(20, 57);
  if (pompaOn) {
    if (jadwalAktif) {
      unsigned long elapsedDetik = (millis() - jadwalMulaiMs) / 1000UL;
      unsigned long totalDetik   = (unsigned long)jadwal.durasi * 60UL;
      long sisaDetik = (long)totalDetik - (long)elapsedDetik;
      if (sisaDetik < 0) sisaDetik = 0;
      display.print("Sisa:");
      display.print(sisaDetik);
      display.print("dtk");
    } else {
      display.print("Pompa ON");
    }
  } else {
    if (!wifiOk) {
      display.print("Offline");
    } else if (modeControl == "Jadwal" && jadwal.jam >= 0) {
      display.printf("Jam %02d:%02d", jadwal.jam, jadwal.menit);
    } else {
      display.print("Pompa OFF");
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
    Serial.println("[BOOT] Sudah pernah pairing — skip BLE.");
    systemState   = STATE_RUNNING;
    modeControl   = "Otomatis";
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    wifiPercobaan = 1;
    prevWiFiRetry = millis();
  } else {
    systemState = STATE_BLE;
    initBLE();
    Serial.println("[BOOT] Menunggu pairing BLE...");
  }
}

// ============================================================
//  LOOP UTAMA
// ============================================================
void loop() {
  unsigned long now = millis();

  // Tombol Boot → hapus pairing & restart
  if (digitalRead(BOOT_PIN) == LOW) {
    delay(50);
    if (digitalRead(BOOT_PIN) == LOW) {
      Serial.println("[BOOT] Reset pairing & restart...");
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

      // Simpan flag paired ke Preferences
      prefs.begin("irigasi", false);
      prefs.putBool("paired", true);
      prefs.end();

      stopBLE();

      systemState = STATE_RUNNING;
      modeControl = "Otomatis";
      systemReady = true;

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
  //  1. BACA SENSOR tiap 1 detik
  // ----------------------------------------------------------
  if (now - prevReadSensor >= 1000) {
    prevReadSensor = now;
    bacaSensor();
  }

  // ----------------------------------------------------------
  //  2. KONTROL POMPA — prioritas tinggi, setiap loop
  // ----------------------------------------------------------
  kontrolPompa();

  // ----------------------------------------------------------
  //  3. CEK JADWAL tiap 3 detik
  // ----------------------------------------------------------
  if (now - prevCekJadwal >= 3000) {
    prevCekJadwal = now;
    cekJadwal();
  }

  // ----------------------------------------------------------
  //  4. BACA FIREBASE tiap 3 detik
  // ----------------------------------------------------------
  if (wifiOk && (now - prevReadFB >= 3000)) {
    prevReadFB = now;
    bacaFirebase();
  }

  // ----------------------------------------------------------
  //  5. KIRIM FIREBASE tiap 5 detik
  // ----------------------------------------------------------
  if (wifiOk && (now - prevUpdateFB >= 5000)) {
    prevUpdateFB = now;
    kirimFirebase();
  }

  // ----------------------------------------------------------
  //  6. UPDATE OLED tiap 300ms
  // ----------------------------------------------------------
  if (now - prevOLED >= 300) {
    prevOLED = now;
    updateOLED();
  }
}
