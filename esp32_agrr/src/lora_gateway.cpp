#include "lora_gateway.h"

// ── Trang thai 10 motor (index 0 = motor 1, ..., index 9 = motor 10) ──
bool motorState[MOTOR_COUNT] = {false};

// ── Flag báo cho mqttTask publish trạng thái khi có thay đổi từ nút vật lý ──
volatile bool motorStatusChanged = false;

// ── LoRa dung Serial2 cua ESP32 ──────────────────────────────
#define LoRaSerial Serial2

// ─────────────────────────────────────────────────────────────
void initLoRa() {
    LoRaSerial.begin(LORA_BAUD, SERIAL_8N1, LORA_RX_PIN, LORA_TX_PIN);
    LoRaSerial.setTimeout(10); // Tránh block 1000ms khi đọc thiếu ký tự \n
    delay(100);
    Serial.printf("[LoRa] Serial2 khoi dong: TX=%d RX=%d BAUD=%d\r\n",
                  LORA_TX_PIN, LORA_RX_PIN, LORA_BAUD);
}

// ─────────────────────────────────────────────────────────────
// Xử lý bản tin bất đồng bộ, trả về true nếu là bản tin async
// ─────────────────────────────────────────────────────────────
bool processAsyncLoRaMessage(String msg) {
    if (msg.startsWith("UPDATE_N3_M")) {
        Serial.printf("[LoRa Async] Nhan: %s\r\n", msg.c_str());
        int mIndex = msg.indexOf("_M");
        if (mIndex != -1) {
            int idStrIdx = mIndex + 2;
            int uscoreIdx = msg.indexOf('_', idStrIdx);
            if (uscoreIdx != -1) {
                int motorId = msg.substring(idStrIdx, uscoreIdx).toInt();
                int stateVal = msg.substring(uscoreIdx + 1).toInt();
                
                if (motorId >= 1 && motorId <= MOTOR_COUNT) {
                    motorState[motorId - 1] = (stateVal == 1);
                    Serial.printf("[LoRa Async] Cap nhat Motor %d -> %s\r\n", motorId, stateVal == 1 ? "ON" : "OFF");
                    // Thay vì gọi publishStatus() trực tiếp (không an toàn khi multi-task),
                    // chỉ set flag — mqttTask sẽ tự phát hiện và publish
                    motorStatusChanged = true;
                }
            }
        }
        return true;
    }
    return false;
}

// ─────────────────────────────────────────────────────────────
// Gui lenh va cho 1 dong phan hoi (ket thuc bang '\n')
// Tra ve chuoi da trim, hoac "" neu timeout
// ─────────────────────────────────────────────────────────────
String loraAsk(const char* cmd, int timeoutMs) {
    // Bước 1: Drain hết message tồn đọng trong UART buffer
    while (LoRaSerial.available()) {
        String msg = LoRaSerial.readStringUntil('\n');
        msg.trim();
        if (msg.length() > 0) processAsyncLoRaMessage(msg);
    }

    // Bước 2: Chờ UART yên lặng ít nhất 30ms trước khi gửi lệnh
    // (tránh lệnh bị chôn vùi giữa cơn lũ UPDATE messages từ STM32)
    // Chờ tối đa 300ms, nếu vẫn còn message thì gửi luôn
    unsigned long quietSince = millis();
    unsigned long waitStart  = millis();
    while (millis() - quietSince < 30) {
        if (millis() - waitStart > 300) break; // timeout bảo vệ
        if (LoRaSerial.available()) {
            String msg = LoRaSerial.readStringUntil('\n');
            msg.trim();
            if (msg.length() > 0) processAsyncLoRaMessage(msg);
            quietSince = millis(); // reset bộ đếm im lặng
        }
    }

    LoRaSerial.printf("%s\n", cmd);
    Serial.printf("[LoRa] Gui: %s\r\n", cmd);

    String response = "";
    unsigned long start = millis();
    while (millis() - start < (unsigned long)timeoutMs) {
        if (LoRaSerial.available()) {
            String msg = LoRaSerial.readStringUntil('\n');
            msg.trim();
            if (msg.length() == 0) continue;
            
            // Neu day la ban tin async (nut bam), xu ly va tiep tuc cho
            if (processAsyncLoRaMessage(msg)) {
                continue;
            } else {
                response = msg;
                break;
            }
        }
    }

    if (response.length() == 0) {
        Serial.printf("[LoRa] TIMEOUT cho phan hoi lenh: %s\r\n", cmd);
        return "";
    }

    Serial.printf("[LoRa] Nhan: %s\r\n", response.c_str());
    return response;
}

// ─────────────────────────────────────────────────────────────
// Dieu khien motor: gui SET_N3_Mx_ON/OFF (Fire and Forget)
// ─────────────────────────────────────────────────────────────
bool loraMotorControl(int motorId, bool state) {
    if (motorId < 1 || motorId > MOTOR_COUNT) {
        Serial.printf("[LoRa] Motor ID khong hop le: %d\r\n", motorId);
        return false;
    }

    // Tao lenh: SET_N3_M1_ON hoac SET_N3_M1_OFF
    char cmd[20];
    snprintf(cmd, sizeof(cmd), "SET_N3_M%d_%s", motorId, state ? "ON" : "OFF");

    // Gửi lệnh thẳng xuống STM32 (Không cần chờ N3_OK vì STM32 đang không gửi ACK)
    LoRaSerial.printf("%s\n", cmd);
    Serial.printf("[LoRa] Gui Motor %d -> %s\r\n", motorId, state ? "ON" : "OFF");

    // Cập nhật trạng thái RAM ngay lập tức
    motorState[motorId - 1] = state;
    
    // Đọc bỏ các ký tự rác (nếu có) trong 10ms
    unsigned long start = millis();
    while (millis() - start < 10) {
        if (LoRaSerial.available()) {
            String msg = LoRaSerial.readStringUntil('\n');
            msg.trim();
            if (msg.length() > 0) processAsyncLoRaMessage(msg);
        }
    }

    return true;
}

// ─────────────────────────────────────────────────────────────
// Kiểm tra sự kiện bất đồng bộ từ LoRa (VD: STM32 gửi trạng thái nút bấm)
// ─────────────────────────────────────────────────────────────
void checkLoRaEvents() {
    while (LoRaSerial.available()) {
        String msg = LoRaSerial.readStringUntil('\n');
        msg.trim();
        if (msg.length() > 0) {
            processAsyncLoRaMessage(msg);
        }
    }
}
