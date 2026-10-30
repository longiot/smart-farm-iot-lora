#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// --- Device ID ---
extern String deviceId;

// --- Firebase Config ---
#define FIREBASE_HOST "FIREBASE_HOST"
#define FIREBASE_AUTH "FIREBASE_AUTH"
#define FIREBASE_PATH "/sensor_data"

// --- Hardware Pins - Display & Storage ---
#define SD_CS_PIN       5
#define LCD_RST_PIN     27

// --- Hardware Pins - Buttons ---
#define BTN_WIFI_PIN       21
#define BTN_SD_EJECT_PIN   33

// --- Relay Pins Removed (Controlled via Node 3 LoRa) ---

// --- LoRa UART (Serial2 = UART2 hardware) ---
#define LORA_TX_PIN     17      // ESP32 TX (U2_TXD) -> LoRa RX
#define LORA_RX_PIN     16      // ESP32 RX (U2_RXD) <- LoRa TX
#define LORA_BAUD       9600    // Phải khớp với STM32 USART2

#define LORA_TIMEOUT_MS 2000

// --- Node ID ---
#define NODE_DHT11  1           // STM32 Node 1: cảm biến DHT11
#define NODE_BH1750 2           // STM32 Node 2: cảm biến BH1750
#define NODE_MOTOR  3           // STM32 Node 3: điều khiển 10 motor

// --- Số lượng motor ---
#define MOTOR_COUNT 3

// --- Time Config ---
extern const long gmtOffset_sec;
extern const int  daylightOffset_sec;

#endif
