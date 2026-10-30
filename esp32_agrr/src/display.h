#ifndef DISPLAY_H
#define DISPLAY_H

#include <TFT_eSPI.h>

extern TFT_eSPI tft;

void initDisplay();
void updateLCD(float temp, float hum, float lux, float soil_moisture, bool online);
void showLCDMessage(const char* msg);

#endif


