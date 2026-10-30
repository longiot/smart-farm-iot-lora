#ifndef MQTT_CONTROL_H
#define MQTT_CONTROL_H

#include <Arduino.h>
#include "config.h"

// ── Trạng thái relay local ───────────────────────────────────
extern bool pumpIsOn;
extern bool shadeIsOn;

// ── Chuỗi lịch hẹn giờ ───────────────────────────────────────
extern String currentScheduleString;

// ── Khởi tạo & vòng lặp MQTT ────────────────────────────────
void initMQTT();
void mqttLoop();

// ── Publish trạng thái relay local ──────────────────────────
void publishStatus();

// ── Publish dữ liệu cảm biến (từ các node LoRa) ─────────────
void publishSensorData(const String& ts, float temp, float hum, float lux, float soil_moisture);

// ── Publish trạng thái motor Node 3 lên MQTT ────────────────
// Gửi JSON tất cả 10 motor sau mỗi lần thay đổi


#endif



