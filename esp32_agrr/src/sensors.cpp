#include "sensors.h"
#include "lora_gateway.h"

// ─────────────────────────────────────────────────────────────
// Đọc DHT11 từ Node 1 qua LoRa
// Giao thức: gửi "GET_N1" → nhận "N1,<temp>,<hum>"
// ─────────────────────────────────────────────────────────────
bool readNodeDHT(float& temp, float& hum) {
    String resp = loraAsk("GET_N1");

    if (resp.length() == 0) return false;

    // Parse "N1,25.0,60.0"
    // Kiểm tra prefix "N1,"
    if (!resp.startsWith("N1,")) {
        Serial.printf("[Sensor] Phản hồi không hợp lệ từ Node 1: %s\r\n", resp.c_str());
        return false;
    }

    String data = resp.substring(3); // Bỏ "N1,"
    int comma = data.indexOf(',');
    if (comma < 0) {
        Serial.printf("[Sensor] Thiếu dấu phẩy trong: %s\r\n", resp.c_str());
        return false;
    }

    temp = data.substring(0, comma).toFloat();
    hum  = data.substring(comma + 1).toFloat();

    Serial.printf("[Node1] T=%.1f°C H=%.1f%%\r\n", temp, hum);
    return true;
}

// ─────────────────────────────────────────────────────────────
// Đọc BH1750 từ Node 2 qua LoRa
// Giao thức: gửi "GET_N2" → nhận "N2,<lux>"
// ─────────────────────────────────────────────────────────────
bool readNodeBH1750(float& lux) {
    String resp = loraAsk("GET_N2");

    if (resp.length() == 0) return false;

    // Parse "N2,850.5"
    if (!resp.startsWith("N2,")) {
        Serial.printf("[Sensor] Phản hồi không hợp lệ từ Node 2: %s\r\n", resp.c_str());
        return false;
    }

    lux = resp.substring(3).toFloat();
    Serial.printf("[Node2] Lux=%.1f\r\n", lux);
    return true;
}

// Doc Do am dat tu Node 4 qua LoRa
// Giao thuc: gui "GET_N4" -> nhan "N4,<moisture>"
bool readNodeSoilMoisture(float& moisture) {
    String resp = loraAsk("GET_N4");

    if (resp.length() == 0) return false;

    // Parse "N4,75" hoac "N4,75.0"
    if (!resp.startsWith("N4,")) {
        Serial.printf("[Sensor] Phan hoi khong hop le tu Node 4: %s\r\n", resp.c_str());
        return false;
    }

    moisture = resp.substring(3).toFloat();
    Serial.printf("[Node4] Soil Moisture=%.1f%%\r\n", moisture);
    return true;
}
