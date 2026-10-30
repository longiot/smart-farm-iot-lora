#ifndef FIRESTORE_H
#define FIRESTORE_H

#include <Arduino.h>

// Gửi một bản ghi sensor realtime lên Firestore
bool firestoreLog(const String& ts, float temp, float hum, float lux, float soil_moisture, bool sdReady, int pendingCount);

// Gửi dữ liệu bù từ hàng chờ offline lên Firestore, trả về true nếu thành công
bool firestoreLogPending(const String& ts, float temp, float hum, float lux, float soil_moisture);

#endif




