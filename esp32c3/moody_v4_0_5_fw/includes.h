int current_buffer_size = 120;

const char *target_ssid = "moody-admin";  // Replace with your target SSID
const char *target_pw = "moody-pw";       // Replace with your target SSID

unsigned long last_prev_val_parsed = 0;
float t_avg = 0.0;
int t_c = 0;

RTC_DATA_ATTR int bootCount = 0;

unsigned long lastPrint = 0;
volatile unsigned long high_time_trig = 0;
volatile unsigned long high_time_prev_trig = 0;
volatile unsigned long low_time_trig = 0;

String BLE_device_name = "unset-till-setup";

byte current_rgb[] = { 0, 0, 0 };
byte target_rgb[] = { 0, 0, 0 };
unsigned long target_rgb_start = 0;
unsigned long last_rgb_loop = 0;

const int button = 0;         //gpio to use to trigger delay
const int wdtTimeout = 1000;  //time in ms to trigger the watchdog
hw_timer_t *timer = NULL;

#ifdef DEBUG_MODE
#define debugPrint(x) Serial.print(x)
#define debugPrintln(x) Serial.println(x)
#else
#define debugPrint(x)
#define debugPrintln(x)
#endif

#include "neopixel.h"
#include "power_mgmt.h"
#include "ota.h"
#include "ble_uart.h"
#include "temp.h"

void set_device_name() {
    String MAC_address = WiFi.macAddress().c_str();

    MAC_address.toUpperCase();
    debugPrint("MAC_address: ");
    debugPrintln(MAC_address);

    BLE_device_name = "MOODY_";
    BLE_device_name += MAC_address[MAC_address.length() - 5];
    BLE_device_name += MAC_address[MAC_address.length() - 4];
    BLE_device_name += MAC_address[MAC_address.length() - 2];
    BLE_device_name += MAC_address[MAC_address.length() - 1];

    debugPrint("BLE_device_name = ");
    debugPrintln(BLE_device_name);
}


