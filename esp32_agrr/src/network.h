#ifndef NETWORK_H
#define NETWORK_H

#include <Arduino.h>

String getTimeString();
bool sendToFirebase(const String &timestamp, float temp, float hum, float lux);

#endif
