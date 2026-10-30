#include "config.h"
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <SD.h>

#include "storage.h"
#include "display.h"
#include "sensors.h"
#include "network.h"
#include "mqtt_control.h"
#include "firestore.h"
#include "lora_gateway.h"

// FreeRTOS
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"

const long gmtOffset_sec     = 7 * 3600;
const int  daylightOffset_sec = 0;

#define SEND_INTERVAL_MS 60000UL

bool sd_mounted = true;

String deviceId = "";

// ── Mutex bảo vệ LoRa UART (Serial2) ─────────────────────────
// sensorTask và loraEventTask đều dùng Serial2
// Mutex đảm bảo chỉ 1 task dùng UART tại một thời điểm
SemaphoreHandle_t loraMutex = nullptr;

// ── Mutex bảo vệ SPI bus (SD card + TFT dùng chung SPI) ──────
SemaphoreHandle_t spiMutex = nullptr;

// ============================================================
// flushPendingToFirebase — gọi trong sensorTask
// ============================================================
static void flushPendingToFirebase() {
    File f = SD.open("/pending.csv", FILE_READ);
    if (!f) return;
    if (f.available()) f.readStringUntil('\n'); // bỏ header
    int total = 0, success = 0;
    while (f.available()) {
        String line = f.readStringUntil('\n');
        line.trim();
        if (line.length() == 0) continue;
        int i1 = line.indexOf(',');
        if (i1 < 0) continue;
        String ts   = line.substring(0, i1);
        String rest = line.substring(i1 + 1);
        int i2 = rest.indexOf(',');  if (i2 < 0) continue;
        float temp  = rest.substring(0, i2).toFloat(); rest = rest.substring(i2 + 1);
        int i3 = rest.indexOf(',');  if (i3 < 0) continue;
        float hum   = rest.substring(0, i3).toFloat(); rest = rest.substring(i3 + 1);
        int i4 = rest.indexOf(',');  if (i4 < 0) continue;
        float lux   = rest.substring(0, i4).toFloat();
        float soil  = rest.substring(i4 + 1).toFloat();
        total++;
        if (firestoreLogPending(ts, temp, hum, lux, soil)) success++;
    }
    f.close();
    if (success == total && total > 0) {
        SD.remove("/pending.csv");
        Serial.println("[Pending] Da flush xong toan bo.");
    }
}

// ============================================================
// sendDataTask — đọc 3 node LoRa, gửi lên cloud, ghi SD
// Chỉ gọi trong sensorTask (đã giữ loraMutex + spiMutex)
// ============================================================
static void sendDataTask() {
    float temp = -999.0, hum = -999.0, lux = -999.0, soil_moisture = -999.0;

    // Lấy loraMutex trước khi thực hiện các loraAsk()
    if (xSemaphoreTake(loraMutex, pdMS_TO_TICKS(2000)) != pdTRUE) {
        Serial.println("[SensorTask] Khong lay duoc loraMutex, bo qua lan do nay.");
        return;
    }

    // Node 1 (DHT11)
    String n1 = loraAsk("GET_N1");
    if (n1.startsWith("N1,")) {
        int idx = n1.indexOf(',', 3);
        if (idx > 0) {
            temp = n1.substring(3, idx).toFloat();
            hum  = n1.substring(idx + 1).toFloat();
        }
    }

    // Node 2 (BH1750)
    String n2 = loraAsk("GET_N2");
    if (n2.startsWith("N2,")) {
        lux = n2.substring(3).toFloat();
    }

    // Node 4 (Độ ẩm đất)
    String n4 = loraAsk("GET_N4");
    if (n4.startsWith("N4,")) {
        soil_moisture = n4.substring(3).toFloat();
    }

    xSemaphoreGive(loraMutex); // Trả loraMutex ngay sau khi xong LoRa

    // Cập nhật LCD (dùng spiMutex)
    String ts = getTimeString();
    if (ts == "No_Time") ts = "1970-01-01 00:00:00";

    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
        updateLCD(temp, hum, lux, soil_moisture, WiFi.status() == WL_CONNECTED);
        xSemaphoreGive(spiMutex);
    }

    // Publish MQTT (gọi được tự do vì publishSensorData chỉ gọi mqttClient.publish)
    publishSensorData(ts, temp, hum, lux, soil_moisture);

    String row = ts + "," + String(temp, 1) + "," + String(hum, 1) + ","
               + String(lux, 1) + "," + String(soil_moisture, 1) + "\n";

    // Gửi Firestore (HTTPS, có thể block 2-5 giây — nhưng MQTT task vẫn chạy độc lập)
    bool sendOk = false;
    if (WiFi.status() == WL_CONNECTED) {
        bool sdIsOk = sd_mounted && sdCardReady;
        int pendingLines = 0;
        if (pendingFileExists()) {
            File f = SD.open("/pending.csv", FILE_READ);
            if (f) {
                while (f.available()) { if (f.read() == '\n') pendingLines++; }
                f.close();
                if (pendingLines > 0) pendingLines--;
            }
        }
        sendOk = firestoreLog(ts, temp, hum, lux, soil_moisture, sdIsOk, pendingLines);
    }

    // Xử lý pending + ghi SD (dùng spiMutex vì SD và TFT dùng chung SPI bus)
    if (sendOk) {
        if (pendingFileExists()) flushPendingToFirebase();
    } else {
        if (sd_mounted) {
            if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
                if (!sdCardReady) initSDCard();
                if (sdCardReady) logPending(row.c_str());
                xSemaphoreGive(spiMutex);
            }
        }
    }

    if (sd_mounted) {
        if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
            if (!sdCardReady) initSDCard();
            if (sdCardReady) {
                if (!logData(row.c_str())) sdCardReady = false;
            }
            xSemaphoreGive(spiMutex);
        }
    }
}

// ============================================================
// checkSchedule — gọi trong mqttTask
// ============================================================
static void checkSchedule() {
    if (currentScheduleString.length() == 0) return;

    struct tm timeinfo;
    if (!getLocalTime(&timeinfo, 10)) return;

    static int lastCheckedMinute = -1;
    if (timeinfo.tm_min == lastCheckedMinute) return;
    lastCheckedMinute = timeinfo.tm_min;

    int currentH = timeinfo.tm_hour;
    int currentM = timeinfo.tm_min;

    int startIdx = 0;
    while (startIdx < (int)currentScheduleString.length()) {
        int pipeIdx = currentScheduleString.indexOf('|', startIdx);
        if (pipeIdx == -1) pipeIdx = currentScheduleString.length();

        String entry = currentScheduleString.substring(startIdx, pipeIdx);
        startIdx = pipeIdx + 1;

        int comma1 = entry.indexOf(',');
        int comma2 = entry.indexOf(',', comma1 + 1);
        int comma3 = entry.indexOf(',', comma2 + 1);

        if (comma1 > 0 && comma2 > 0 && comma3 > 0) {
            String dev        = entry.substring(0, comma1);
            String onTimeStr  = entry.substring(comma1 + 1, comma2);
            String offTimeStr = entry.substring(comma2 + 1, comma3);
            String enStr      = entry.substring(comma3 + 1);

            if (enStr == "1") {
                int colon1 = onTimeStr.indexOf(':');
                int onH = onTimeStr.substring(0, colon1).toInt();
                int onM = onTimeStr.substring(colon1 + 1).toInt();

                int colon2 = offTimeStr.indexOf(':');
                int offH = offTimeStr.substring(0, colon2).toInt();
                int offM = offTimeStr.substring(colon2 + 1).toInt();

                // Lấy loraMutex khi cần gửi lệnh motor
                auto sendMotorCmd = [&](int id, bool state, const char* label) {
                    if (xSemaphoreTake(loraMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
                        loraMotorControl(id, state);
                        xSemaphoreGive(loraMutex);
                        Serial.printf("[Schedule] %s Thiet bi %d\n", label, id);
                        publishStatus();
                    }
                };

                if (currentH == onH && currentM == onM) {
                    if (dev == "dev1" && !motorState[0]) sendMotorCmd(1, true,  "TU DONG BAT");
                    else if (dev == "dev2" && !motorState[1]) sendMotorCmd(2, true,  "TU DONG BAT");
                    else if (dev == "dev3" && !motorState[2]) sendMotorCmd(3, true,  "TU DONG BAT");
                } else if (currentH == offH && currentM == offM) {
                    if (dev == "dev1" && motorState[0])  sendMotorCmd(1, false, "TU DONG TAT");
                    else if (dev == "dev2" && motorState[1])  sendMotorCmd(2, false, "TU DONG TAT");
                    else if (dev == "dev3" && motorState[2])  sendMotorCmd(3, false, "TU DONG TAT");
                }
            }
        }
    }
}

// ============================================================
// TASK 1 — mqttTask (Core 0, ưu tiên cao nhất)
// Chịu trách nhiệm: MQTT loop, nhận lệnh điều khiển, lịch hẹn giờ
// KHÔNG BAO GIỜ bị block bởi LoRa hay HTTP
// ============================================================
static void mqttTask(void* param) {
    static unsigned long lastHeartbeat = 0;

    for (;;) {
        mqttLoop();
        checkSchedule();

        // Kiểm tra flag từ loraEventTask — publish khi nút vật lý thay đổi motor
        if (motorStatusChanged) {
            motorStatusChanged = false;
            publishStatus();
        }

        // Heartbeat mỗi 10 giây
        unsigned long now = millis();
        if (now - lastHeartbeat >= 10000) {
            lastHeartbeat = now;
            Serial.printf("[mqttTask] alive | t=%lus | WiFi=%s\r\n",
                now / 1000,
                WiFi.status() == WL_CONNECTED ? "OK" : "NO");
        }

        vTaskDelay(pdMS_TO_TICKS(10)); // nhường CPU 10ms, không busy-wait
    }
}

// ============================================================
// TASK 2 — sensorTask (Core 1, ưu tiên thấp)
// Chịu trách nhiệm: poll cảm biến mỗi 60s, gửi Firestore, ghi SD
// HTTP HTTPS block tối đa vài giây — mqttTask vẫn chạy độc lập
// ============================================================
static void sensorTask(void* param) {
    // Chờ 30 giây sau khi khởi động để WiFi/NTP ổn định
    vTaskDelay(pdMS_TO_TICKS(30000));
    Serial.println("[sensorTask] Bat dau vong lap doc cam bien.");

    for (;;) {
        sendDataTask();
        // Chờ SEND_INTERVAL_MS, nhường CPU hoàn toàn trong thời gian này
        vTaskDelay(pdMS_TO_TICKS(SEND_INTERVAL_MS));
    }
}

// ============================================================
// TASK 3 — loraEventTask (Core 1, ưu tiên trung bình)
// Chịu trách nhiệm: lắng nghe bản tin async từ STM32 (nút bấm vật lý)
// ============================================================
static void loraEventTask(void* param) {
    for (;;) {
        // Chỉ lấy mutex nếu sensorTask không đang dùng LoRa UART
        if (xSemaphoreTake(loraMutex, pdMS_TO_TICKS(10)) == pdTRUE) {
            checkLoRaEvents();
            xSemaphoreGive(loraMutex);
        }
        vTaskDelay(pdMS_TO_TICKS(50)); // kiểm tra mỗi 50ms — đủ nhanh cho nút bấm
    }
}

// ============================================================
// TASK 4 — buttonTask (Core 0, ưu tiên thấp)
// Chịu trách nhiệm: nút WiFi config, nút eject SD
// Tách ra task riêng để không ảnh hưởng mqttTask
// ============================================================
static void buttonTask(void* param) {
    static unsigned long wifiBtnStartTime = 0;
    static bool isWifiBtnPressed      = false;
    static bool wifiActionTriggered   = false;
    static unsigned long lastSdEjectPress = 0;
    static bool lastSdBtnState        = HIGH;

    for (;;) {
        // --- Nút WiFi Config (nhấn giữ 3 giây) ---
        if (digitalRead(BTN_WIFI_PIN) == LOW) {
            if (!isWifiBtnPressed) {
                isWifiBtnPressed    = true;
                wifiBtnStartTime    = millis();
                wifiActionTriggered = false;
            } else {
                if (millis() - wifiBtnStartTime > 3000 && !wifiActionTriggered) {
                    wifiActionTriggered = true;
                    Serial.println("[SYS] Bat dau che do cau hinh WiFi (On-Demand)...");

                    if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
                        tft.fillScreen(TFT_BLACK);
                        tft.setTextColor(TFT_YELLOW, TFT_BLACK);
                        tft.setTextSize(1);
                        tft.setCursor(5, 70);  tft.print("Chuyen sang che do");
                        tft.setCursor(5, 85);  tft.print("CAU HINH WIFI");
                        tft.setCursor(5, 110); tft.print("AP: ESP32_NONG_NGHIEP");
                        xSemaphoreGive(spiMutex);
                    }

                    WiFiManager wm;
                    wm.setConfigPortalTimeout(180);
                    if (wm.startConfigPortal("ESP32_NONG_NGHIEP")) {
                        Serial.println("[WiFi] Da luu cau hinh moi. Dang khoi dong lai...");
                        delay(1000);
                        ESP.restart();
                    } else {
                        Serial.println("[WiFi] Het thoi gian cho cau hinh.");
                    }
                }
            }
        } else {
            isWifiBtnPressed = false;
        }

        // --- Nút Rút thẻ SD an toàn ---
        bool currentSdBtnState = digitalRead(BTN_SD_EJECT_PIN);
        if (currentSdBtnState == LOW && lastSdBtnState == HIGH &&
            (millis() - lastSdEjectPress > 50)) {
            lastSdEjectPress = millis();
            if (sd_mounted) {
                Serial.println("[SD] Ngat ket noi the SD an toan...");
                SD.end();
                sd_mounted = false;
                if (xSemaphoreTake(spiMutex, pdMS_TO_TICKS(500)) == pdTRUE) {
                    showLCDMessage("SD SAFE TO REMOVE");
                    xSemaphoreGive(spiMutex);
                }
            }
        }
        lastSdBtnState = currentSdBtnState;

        vTaskDelay(pdMS_TO_TICKS(20)); // debounce + nhường CPU
    }
}

// ============================================================
// setup()
// ============================================================
void setup() {
    Serial.begin(115200);

    // Sinh Device ID từ MAC address
    uint8_t mac[6];
    WiFi.macAddress(mac);
    char idStr[20];
    snprintf(idStr, sizeof(idStr), "ESP32_%02X%02X%02X%02X%02X%02X",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    deviceId = String(idStr);

    Serial.println("\n=========================================");
    Serial.printf("DEVICE ID: %s\n", deviceId.c_str());
    Serial.println("=========================================\n");

    // --- Tạo Mutex trước khi khởi tạo bất kỳ module nào ---
    loraMutex = xSemaphoreCreateMutex();
    spiMutex  = xSemaphoreCreateMutex();

    // --- GPIO ---
    pinMode(BTN_WIFI_PIN,    INPUT_PULLUP);
    pinMode(BTN_SD_EJECT_PIN, INPUT_PULLUP);
    pinMode(SD_CS_PIN, OUTPUT);
    digitalWrite(SD_CS_PIN, HIGH);

    // --- Khởi tạo các module ---
    initDisplay();
    initLoRa();
    initSDCard();

    currentScheduleString = loadSchedules();
    Serial.print("[NVS] Lich su hen gio: ");
    Serial.println(currentScheduleString);
    Serial.flush();
    delay(500);

    // --- WiFi ---
    WiFi.mode(WIFI_STA);
    WiFi.setAutoConnect(true);
    WiFi.setAutoReconnect(true);
    WiFi.begin();

    WiFi.onEvent([](WiFiEvent_t event, WiFiEventInfo_t info) {
        if (event == ARDUINO_EVENT_WIFI_STA_GOT_IP) {
            configTime(gmtOffset_sec, daylightOffset_sec, "pool.ntp.org", "time.nist.gov");
            Serial.println("[WiFi] Connected, NTP requested.");
        }
    });

    initMQTT();
    Serial.println("[SYS] Khoi tao xong. Tao FreeRTOS tasks...");
    Serial.flush();

    // ── Tạo các FreeRTOS Task ───────────────────────────────────
    // xTaskCreatePinnedToCore(func, name, stackSize, param, priority, handle, core)
    //   Core 0 = Protocol CPU (WiFi/BT nền cũng dùng Core 0)
    //   Core 1 = Application CPU
    //   Priority: số cao = ưu tiên cao hơn

    xTaskCreatePinnedToCore(mqttTask,      "mqttTask",      6144, NULL, 3, NULL, 0);
    xTaskCreatePinnedToCore(buttonTask,    "buttonTask",    4096, NULL, 1, NULL, 0);
    xTaskCreatePinnedToCore(sensorTask,    "sensorTask",    8192, NULL, 1, NULL, 1);
    xTaskCreatePinnedToCore(loraEventTask, "loraEventTask", 2048, NULL, 2, NULL, 1);

    Serial.println("[SYS] Tat ca task da duoc tao. loop() se idle.");
}

// ============================================================
// loop() — không làm gì, các task FreeRTOS đã quản lý tất cả
// ============================================================
void loop() {
    vTaskDelay(pdMS_TO_TICKS(1000)); // idle, tránh watchdog reset
}