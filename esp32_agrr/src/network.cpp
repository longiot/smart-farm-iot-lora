#include "network.h"
#include "config.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>

String getTimeString() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "No_Time";
  char buf[50];
  strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", &timeinfo);
  return String(buf);
}

bool sendToFirebase(const String &timestamp, float temp, float hum, float lux) {
  if (WiFi.status() != WL_CONNECTED) return false;

  String nodeKey = timestamp;
  nodeKey.replace(" ", "_");
  nodeKey.replace(":", "-");

  String payload = "{\"temp\":" + String(temp, 1) +
                   ",\"humidity\":" + String(hum, 1) +
                   ",\"light\":" + String(lux, 1) + "}";

  String url = "https://" + String(FIREBASE_HOST) + FIREBASE_PATH + "/" +
               nodeKey + ".json?auth=" + FIREBASE_AUTH;

  WiFiClientSecure client;
  client.setInsecure(); // Lưu ý: để bảo mật tốt hơn nên dùng Root CA thay vì setInsecure

  HTTPClient http;
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  int code = http.PUT(payload);
  http.end();

  if (code >= 200 && code < 300) return true;
  Serial.printf("[Firebase] HTTP %d\n", code);
  return false;
}
