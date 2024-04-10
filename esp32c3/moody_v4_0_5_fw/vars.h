#ifdef DEBUG_MODE
#define debugPrint(x) Serial.print(x)
#define debugPrintln(x) Serial.println(x)
#else
#define debugPrint(x)
#define debugPrintln(x)
#endif

#include <WiFi.h>


int current_buffer_size = 120;


unsigned long last_prev_val_parsed = 0;
float t_avg = 0.0;
int t_c = 0;


RTC_DATA_ATTR int bootCount = 0;

unsigned long lastPrint = 0;
volatile unsigned long high_time_trig = 0;
volatile unsigned long high_time_prev_trig = 0;
volatile unsigned long low_time_trig = 0;
volatile unsigned long high_time = 0;
volatile unsigned long last_high_time = 0;
volatile unsigned long low_time = 0;
volatile unsigned long high_time_start = 0;
volatile unsigned long low_time_start = 0;
volatile long has_interrupted_f = 0;
volatile long has_interrupted_r = 0;
volatile int c = 0;
volatile int T = 0.0;
volatile float d = 0.0;
volatile int ttteeempp = 0;


String BLE_device_name = "unset";

byte current_rgb[] = { 0, 0, 0 };
byte target_rgb[] = { 0, 0, 0 };
unsigned long target_rgb_start = 0;
unsigned long last_rgb_loop = 0;


// // String name = loadOrStoreName();
// // // Serial.print("name = ");
// String MAC_address = WiFi.macAddress().c_str();
// //BLEDevice::getAddress().toString().c_str();
// MAC_address.toUpperCase();
// debugPrint("MAC_address: ");
// debugPrintln(MAC_address);

// BLE_device_name = "Moody ";
// BLE_device_name += MAC_address[MAC_address.length() - 5];
// BLE_device_name += MAC_address[MAC_address.length() - 4];
// BLE_device_name += MAC_address[MAC_address.length() - 2];
// BLE_device_name += MAC_address[MAC_address.length() - 1];

// debugPrint("BLE_device_name = ");
// debugPrintln(BLE_device_name);

void set_device_name() {
  // if (BLE_device_name == "unset moody") {

    // String name = loadOrStoreName();
    // // Serial.print("name = ");
    String MAC_address = WiFi.macAddress().c_str();
    //BLEDevice::getAddress().toString().c_str();
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
  // }
}