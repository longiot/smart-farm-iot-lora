#ifndef LORA_GATEWAY_H
#define LORA_GATEWAY_H

#include <Arduino.h>
#include "config.h"

// ── Khởi tạo UART LoRa ───────────────────────────────────────
void initLoRa();

// ── Gửi lệnh và chờ phản hồi từ node ────────────────────────
// Trả về chuỗi phản hồi, chuỗi rỗng nếu timeout
String loraAsk(const char* cmd, int timeoutMs = LORA_TIMEOUT_MS);

// ── Gửi lệnh bật/tắt motor tới Node 3 ───────────────────────
// motorId: 1–10, state: true = ON, false = OFF
// Trả về true nếu Node 3 xác nhận OK
bool loraMotorControl(int motorId, bool state);

// ── Kiểm tra và xử lý các bản tin bất đồng bộ từ STM32 ─────
void checkLoRaEvents();

// ── Lấy trạng thái motor hiện tại (lưu trong RAM) ────────────
// motorId: 1–10 → index 0–9
extern bool motorState[MOTOR_COUNT];

// ── Flag báo hiệu cho mqttTask cần publish trạng thái motor ──
// Set true khi nút bấm vật lý STM32 thay đổi trạng thái
extern volatile bool motorStatusChanged;

#endif
