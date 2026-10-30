#include "firestore.h"
#include "network.h"
#include "config.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

// ── Firestore REST API config ────────────────────────────────────
static const char* FS_HOST       = "firestore.googleapis.com";
static const char* FS_PROJECT    = "appnongnghiep-f9d6f";
static const char* FS_API_KEY    = "FS_API_KEY";
static const char* FS_COLLECTION = "sensor_logs";

// ── Hàm nội bộ: POST một JSON body lên Firestore, trả về true nếu thành công ──
static bool postToFirestore(const String& body) {
  String url = "https://";
  url += FS_HOST;
  url += "/v1/projects/";
  url += FS_PROJECT;
  url += "/databases/(default)/documents/devices/";
  url += deviceId;
  url += "/sensor_logs";
  url += "?key=";
  url += FS_API_KEY;

  WiFiClientSecure client;
  client.setInsecure();
  client.setTimeout(8);

  HTTPClient http;
  if (!http.begin(client, url)) {
    Serial.println("[Firestore] http.begin thất bại");
    return false;
  }

  http.addHeader("Content-Type", "application/json");
  int code = http.POST(body);
  bool ok = (code == 200 || code == 201);

  if (ok) {
    Serial.printf("[Firestore] ✅ Saved (HTTP %d)\n", code);
  } else {
    Serial.printf("[Firestore] ❌ HTTP %d: %s\n", code, http.getString().c_str());
  }

  http.end();
  return ok;
}

// ── Gửi data realtime lên Firestore ────────────────────────────────────────
bool firestoreLog(const String& ts, float temp, float hum, float lux, float soil_moisture, bool sdReady, int pendingCount) {
  if (WiFi.status() != WL_CONNECTED) return false;

  String nowIso = ts;
  if (nowIso.indexOf("_boot") != -1) {
    nowIso = getTimeString();
  }
  nowIso.replace(' ', 'T');
  nowIso += "+07:00";

  String body = "{\"fields\":{";
  body += "\"ts\":{\"stringValue\":\"" + ts + "\"},";
  body += "\"temp\":{" + String(temp <= -999.0 ? "\"nullValue\":null" : "\"doubleValue\":" + String(temp, 1)) + "},";
  body += "\"hum\":{" + String(hum <= -999.0 ? "\"nullValue\":null" : "\"doubleValue\":" + String(hum, 1)) + "},";
  body += "\"lux\":{" + String(lux <= -999.0 ? "\"nullValue\":null" : "\"doubleValue\":" + String(lux, 1)) + "},";
  body += "\"soil\":{" + String(soil_moisture <= -999.0 ? "\"nullValue\":null" : "\"doubleValue\":" + String(soil_moisture, 1)) + "},";
  body += "\"sd\":{\"integerValue\":\"" + String(sdReady ? 1 : 0) + "\"},";
  body += "\"pending\":{\"integerValue\":\"" + String(pendingCount) + "\"},";
  body += "\"createdAt\":{\"timestampValue\":\"" + nowIso + "\"}";
  body += "}}";

  return postToFirestore(body);
}

// ── Gửi data từ hàng chờ pending lên Firestore, trả về true nếu OK ──
bool firestoreLogPending(const String& ts, float temp, float hum, float lux, float soil_moisture) {
  if (WiFi.status() != WL_CONNECTED) return false;

  // Giữ nguyên timestamp gốc (giờ lúc offline) để lịch sử chính xác
  String nowIso = ts;
  if (nowIso.indexOf("_boot") != -1) {
    nowIso = getTimeString(); // Nếu offline chưa có giờ, dùng giờ hiện tại khi đẩy
  }
  nowIso.replace(' ', 'T');
  nowIso += "+07:00";

  String body = "{\"fields\":{";
  body += "\"ts\":{\"stringValue\":\"" + ts + "\"},";
  body += "\"temp\":{\"doubleValue\":" + String(temp, 2) + "},";
  body += "\"hum\":{\"doubleValue\":" + String(hum, 2) + "},";
  body += "\"lux\":{\"doubleValue\":" + String(lux, 2) + "},";
  body += "\"sd\":{\"integerValue\":\"1\"},";       // đánh dấu gốc từ SD
  body += "\"pending\":{\"integerValue\":\"1\"},";   // đánh dấu là bản ghi bù
  body += "\"createdAt\":{\"timestampValue\":\"" + nowIso + "\"}";
  body += "}}";

  return postToFirestore(body);
}




