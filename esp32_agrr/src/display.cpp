#include "display.h"

TFT_eSPI tft = TFT_eSPI();

void initDisplay() {
  tft.init();
  tft.setRotation(1);
  tft.fillScreen(TFT_BLACK);

  tft.setTextColor(TFT_WHITE, TFT_BLACK);
  tft.setTextSize(2);
  tft.setCursor(10, 10);
  tft.print("Booting...");
}

void updateLCD(float temp, float hum, float lux, float soil_moisture,
               bool online) {
  tft.fillScreen(TFT_BLACK);

  int w = tft.width();
  int h = tft.height();
  int col1 = 5;
  int col2 = w / 2 + 5;

  // Header
  tft.fillRect(0, 0, w, 20, TFT_NAVY);
  tft.setTextColor(TFT_WHITE, TFT_NAVY);
  tft.setTextSize(1);
  tft.setCursor(w / 2 - 40, 6);
  tft.print("SMART GARDEN");

  // Hang 1: Nhiet do (Cot 1) & Do am (Cot 2)
  int row1_title = 25;
  int row1_val = 35;

  // Temp
  tft.setTextColor(TFT_RED, TFT_BLACK);
  tft.setTextSize(1);
  tft.setCursor(col1, row1_title);
  tft.print("NHIET DO");
  tft.setTextSize(2);
  tft.setCursor(col1, row1_val);
  if (isnan(temp))
    tft.print("--");
  else
    tft.printf("%.1fC", temp);

  // Hum
  tft.setTextColor(TFT_BLUE, TFT_BLACK);
  tft.setTextSize(1);
  tft.setCursor(col2, row1_title);
  tft.print("DO AM");
  tft.setTextSize(2);
  tft.setCursor(col2, row1_val);
  if (isnan(hum))
    tft.print("--");
  else
    tft.printf("%.1f%%", hum);

  // Hang 2: Anh sang (Cot 1) & Do am dat (Cot 2)
  int row2_title = 65;
  int row2_val = 75;

  // Lux
  tft.setTextColor(TFT_YELLOW, TFT_BLACK);
  tft.setTextSize(1);
  tft.setCursor(col1, row2_title);
  tft.print("ANH SANG");
  tft.setTextSize(2);
  tft.setCursor(col1, row2_val);
  if (lux < 0)
    tft.print("--");
  else if (lux >= 1000)
    tft.printf("%.1fk", lux / 1000.0);
  else
    tft.printf("%.0f", lux);

  // Soil
  tft.setTextColor(TFT_GREEN, TFT_BLACK);
  tft.setTextSize(1);
  tft.setCursor(col2, row2_title);
  tft.print("DO AM DAT");
  tft.setTextSize(2);
  tft.setCursor(col2, row2_val);
  if (soil_moisture < 0)
    tft.print("--");
  else
    tft.printf("%.0f%%", soil_moisture);

  // Status (Day cung)
  tft.drawFastHLine(0, h - 20, w, TFT_DARKGREY);
  tft.setTextSize(1);
  if (online) {
    tft.setTextColor(TFT_GREEN, TFT_BLACK);
    tft.setCursor(5, h - 14);
    tft.print("[ONLINE]");
  } else {
    tft.setTextColor(TFT_RED, TFT_BLACK);
    tft.setCursor(5, h - 14);
    tft.print("[OFFLINE]");
  }
}

void showLCDMessage(const char *msg) {
  int w = tft.width();
  int h = tft.height();
  tft.fillRect(0, h / 2 - 20, w, 40, TFT_RED);
  tft.setTextColor(TFT_WHITE, TFT_RED);
  tft.setTextSize(1);
  tft.setCursor(10, h / 2 - 5);
  tft.print(msg);
}