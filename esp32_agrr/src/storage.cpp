#include "storage.h"
#include "config.h"
#include <SD.h>
#include <SPI.h>
#include <Preferences.h>

bool sdCardReady = false;

static bool appendFile(fs::FS &fs, const char *path, const char *message) {
  File file = fs.open(path, FILE_APPEND);
  if (!file) return false;
  bool ok = file.print(message);
  file.close();
  return ok;
}

void initSDCard() {
  Serial.print("[SD] Ket noi... ");
  if (!SD.begin(SD_CS_PIN, SPI, 4000000)) {
    Serial.println("THAT BAI");
    sdCardReady = false;
    return;
  }
  Serial.println("OK");
  sdCardReady = true;
  if (!SD.exists("/data.csv")) {
    appendFile(SD, "/data.csv", "Time,Temp(C),Hum(%),Light(lux)\n");
  }
}

void endSDCard() {
  SD.end();
  sdCardReady = false;
}

bool logData(const char* row) {
  if (!sdCardReady) return false;
  return appendFile(SD, "/data.csv", row);
}

// ============================================================
// Pending Queue — Dong bo bu len Firebase khi WiFi khoi phuc
// ============================================================

bool logPending(const char* row) {
  if (!sdCardReady) return false;
  // Tao header neu file chua ton tai
  if (!SD.exists("/pending.csv")) {
    appendFile(SD, "/pending.csv", "Time,Temp(C),Hum(%),Light(lux)\n");
  }
  return appendFile(SD, "/pending.csv", row);
}

bool pendingFileExists() {
  if (!sdCardReady) return false;
  return SD.exists("/pending.csv");
}

void deletePendingFile() {
  if (!sdCardReady) return;
  SD.remove("/pending.csv");
  Serial.println("[Pending] Da xoa file pending.csv.");
}

// ============================================================
// NVS Storage — Luu tru lich hen gio vao bo nho vinh vien
// ============================================================
void saveSchedules(const String& payload) {
  Preferences prefs;
  prefs.begin("agri_schedules", false);
  prefs.putString("data", payload);
  prefs.end();
  Serial.println("[NVS] Da luu lich hen vao bo nho flash.");
}

String loadSchedules() {
  Preferences prefs;
  prefs.begin("agri_schedules", true);
  String payload = prefs.getString("data", "");
  prefs.end();
  return payload;
}


