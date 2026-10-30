#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>

// Doc DHT11 tu Node 1 qua LoRa
bool readNodeDHT(float& temp, float& hum);

// Doc BH1750 tu Node 2 qua LoRa
bool readNodeBH1750(float& lux);

// Doc Do am dat tu Node 4 qua LoRa
bool readNodeSoilMoisture(float& moisture);

#endif
