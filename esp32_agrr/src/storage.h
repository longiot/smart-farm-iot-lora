#ifndef STORAGE_H
#define STORAGE_H

#include <Arduino.h>

extern bool sdCardReady;

void initSDCard();
void endSDCard();
bool logData(const char* row);

// --- Pending Queue (Offline → Firebase sync khi khôi phục WiFi) ---
bool logPending(const char* row);   // Ghi 1 dòng vào /pending.csv (tạo header nếu chưa có)
bool pendingFileExists();           // Kiểm tra /pending.csv có tồn tại trên SD không
void deletePendingFile();           // Xóa /pending.csv sau khi đã đẩy hết lên Firebase

// --- NVS Storage cho Hẹn giờ (Offline Persistence) ---
void saveSchedules(const String& payload);
String loadSchedules();

#endif

