
/*
What works:
- temp
- BLE UART
- power on / off
- neopixel
- wifi 
- battery

TODO:
- (fw update)
- Standalone mode

hardware

schakelaar: GND en 3.3V
transistor voor sensoren 3.3V gestuurd via de power schakelaar ook > https://aosmd.com/res/datasheets/AOSS32334C.pdf

*/

// #define BleDeviceName "m033"

#define NEOPIXEL_PIN D10
#define TEMP_PWM_PIN D8
#define WAKE_UP_PIN D1
#define BATTERY_PIN A2

#define SCAN_WIFI false
#define DEBUG_MODE true

#define MAX_BUFFER_SIZE 3 * 60 * 60 * 2  // 3h times 60m times 60s times 2timespersecond

#include "vars.h"
#include "neopixel.h"
#include "power_mgmt.h"
#include "ota.h"
#include "ble_uart.h"
#include "temp.h"

void setup() {
#ifdef DEBUG_MODE
  Serial.begin(115200);
#endif
  pinMode(BATTERY_PIN, INPUT);  // ADC
  delay(500);
  setup_neopixel();
  if (SCAN_WIFI) {
    scan_and_try_connect();
  }
  setup_sleep();
  setup_ble();
  setup_watchdog();
}

void loop() {
  loop_sleep();
  loop_temp();
  loop_ble();
}
