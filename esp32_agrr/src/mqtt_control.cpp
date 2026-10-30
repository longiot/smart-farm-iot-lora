#include "mqtt_control.h"
#include "config.h"
#include "storage.h"
#include "lora_gateway.h"
#include <WiFi.h>
#include <PubSubClient.h>

// --- Topics (phai khop voi Flutter app) ---
static String topicSensor;
static String topicStatus;
static String topicSchedule;

// Topics dieu khien 3 thiet bi (Node 3)
static String topicControlDev1;
static String topicControlDev2;
static String topicControlDev3;

// --- Broker ---
static const char* MQTT_BROKER = "broker.hivemq.com";
static const int   MQTT_PORT   = 1883;

static WiFiClient   wifiClient;
static PubSubClient mqttClient(wifiClient);

// --- Chuoi lich hen gio tu MQTT ---
String currentScheduleString = "";

// ============================================================
// Callback nhan lenh tu App qua MQTT
// ============================================================
static void onMqttMessage(char* topic, byte* payload, unsigned int length) {
    String msg;
    for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
    msg.trim();

    Serial.printf("[MQTT] Nhan: %s -> %s\r\n", topic, msg.c_str());

    // --- Lich hen gio ---
    if (String(topic) == topicSchedule) {
        currentScheduleString = msg;
        saveSchedules(msg);
        Serial.printf("[Schedule] Da cap nhat lich moi: %s\r\n", msg.c_str());
    }
    // --- Dieu khien thiet bi Node 3 ---
    else if (String(topic) == topicControlDev1) {
        bool state = (msg == "ON");
        Serial.printf("[Motor] Lenh tu App: DEV1 -> %s\r\n", state ? "ON" : "OFF");
        if (loraMotorControl(1, state)) publishStatus();
    }
    else if (String(topic) == topicControlDev2) {
        bool state = (msg == "ON");
        Serial.printf("[Motor] Lenh tu App: DEV2 -> %s\r\n", state ? "ON" : "OFF");
        if (loraMotorControl(2, state)) publishStatus();
    }
    else if (String(topic) == topicControlDev3) {
        bool state = (msg == "ON");
        Serial.printf("[Motor] Lenh tu App: DEV3 -> %s\r\n", state ? "ON" : "OFF");
        if (loraMotorControl(3, state)) publishStatus();
    }
}

// ============================================================
// Publish trang thai 3 thiet bi Node 3
// ============================================================
void publishStatus() {
    if (!mqttClient.connected()) return;
    String json = "{\"dev1\":" + String(motorState[0] ? 1 : 0) +
                  ",\"dev2\":" + String(motorState[1] ? 1 : 0) +
                  ",\"dev3\":" + String(motorState[2] ? 1 : 0) + "}";
    mqttClient.publish(topicStatus.c_str(), json.c_str(), true);
}

// ============================================================
// Ket noi / Reconnect MQTT
// ============================================================
static void reconnectMQTT() {
    if (WiFi.status() != WL_CONNECTED) return;
    if (mqttClient.connected()) return;

    Serial.print("[MQTT] Dang ket noi... ");
    String clientId = "esp32_agri_device_" + String(random(0xffff), HEX);
    if (mqttClient.connect(clientId.c_str())) {
        Serial.println("OK");
        mqttClient.subscribe(topicSchedule.c_str());
        mqttClient.subscribe(topicControlDev1.c_str());
        mqttClient.subscribe(topicControlDev2.c_str());
        mqttClient.subscribe(topicControlDev3.c_str());
        publishStatus();
    } else {
        Serial.printf("That bai (rc=%d)\r\n", mqttClient.state());
    }
}

// ============================================================
// Publish du lieu cam bien tu cac node LoRa
// ============================================================
void publishSensorData(const String& ts, float temp, float hum, float lux, float soil_moisture) {
    if (!mqttClient.connected()) return;

    String json = "{";
    json += "\"ts\":\""   + ts + "\",";
    json += "\"temp\":"   + (temp <= -999.0 ? "null" : String(temp, 1)) + ",";
    json += "\"hum\":"    + (hum <= -999.0 ? "null" : String(hum, 1)) + ",";
    json += "\"lux\":"    + (lux <= -999.0 ? "null" : String(lux, 1)) + ",";
    json += "\"soil\":"   + (soil_moisture <= -999.0 ? "null" : String(soil_moisture, 1)) + "," +
            "\"sd\":"     + String(sdCardReady ? 1 : 0) + "," +
            "\"pending\":" + String(pendingFileExists() ? 1 : 0) + "}";

    mqttClient.publish(topicSensor.c_str(), json.c_str(), true);
    Serial.printf("[MQTT] Sensor data (retain): %s\r\n", json.c_str());
}

// ============================================================
// initMQTT
// ============================================================
void initMQTT() {
    // Khoi tao topics dong theo Device ID
    topicSensor = "esp32agri/" + deviceId + "/sensor/data";
    topicStatus = "esp32agri/" + deviceId + "/status";
    topicSchedule = "esp32agri/" + deviceId + "/schedule";
    topicControlDev1 = "esp32agri/" + deviceId + "/control/dev1";
    topicControlDev2 = "esp32agri/" + deviceId + "/control/dev2";
    topicControlDev3 = "esp32agri/" + deviceId + "/control/dev3";

    mqttClient.setServer(MQTT_BROKER, MQTT_PORT);
    mqttClient.setCallback(onMqttMessage);
    mqttClient.setKeepAlive(30);
    Serial.printf("[MQTT] Broker: %s:%d\r\n", MQTT_BROKER, MQTT_PORT);
}

// ============================================================
// mqttLoop – goi trong loop()
// ============================================================
void mqttLoop() {
    static unsigned long lastReconnect = 0;
    if (!mqttClient.connected()) {
        unsigned long now = millis();
        if (now - lastReconnect > 5000) {
            lastReconnect = now;
            reconnectMQTT();
        }
    }
    mqttClient.loop();
}
