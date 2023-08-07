#include "sys/time.h"
#include "BLEDevice.h"
#include "BLEUtils.h"
#include "BLEServer.h"
#include "BLEBeacon.h"
#include "esp_sleep.h"
#include <Adafruit_NeoPixel.h>
#define PIN D10

Adafruit_NeoPixel pixels = Adafruit_NeoPixel(1, PIN, NEO_GRB + NEO_KHZ800);


#define GPIO_DEEP_SLEEP_DURATION 3        // sleep x seconds and then wake up
RTC_DATA_ATTR static time_t last;         // remember last boot in RTC Memory
RTC_DATA_ATTR static uint32_t bootcount;  // remember number of boots in RTC Memory

// See the following for generating UUIDs:
// https://www.uuidgenerator.net/ 3
BLEAdvertising *pAdvertising;  // BLE Advertisement type
struct timeval now;

#define BEACON_UUID "87b99b2c-90fd-11e9-bc42-526af7764f64"  // UUID 1 128-Bit (may use linux tool uuidgen or random numbers via https://www.uuidgenerator.net/ 3)
void setBeacon() {


   char beacon_data[22];
  uint16_t beconUUID = 0xFEAA;
  uint16_t volt = 3300 + bootcount;  // 3300mV = 3.3V
  uint16_t temp = (uint16_t)((float)23.00);
  uint32_t tmil = now.tv_sec * 10;
  // uint8_t temp_farenheit;
  // float temp_celsius;

  // // temp_farenheit= temprature_sens_read();
  // // temp_celsius = ( temp_farenheit - 32 ) / 1.8;
  // // temp = (uint16_t)(temp_celsius);

  // BLEAdvertisementData oAdvertisementData = BLEAdvertisementData();

  // oAdvertisementData.setFlags(0x06); // GENERAL_DISC_MODE 0x02 | BR_EDR_NOT_SUPPORTED 0x04
  // oAdvertisementData.setCompleteServices(BLEUUID(beconUUID));

  beacon_data[0] = 0x20;                              // Eddystone Frame Type (Unencrypted Eddystone-TLM)
  beacon_data[1] = 0x00;                              // TLM version
  beacon_data[2] = (volt >> 8);                       // Battery voltage, 1 mV/bit i.e. 0xCE4 = 3300mV = 3.3V
  beacon_data[3] = (volt & 0xFF);                     //
  beacon_data[4] = (temp & 0xFF);                     // Beacon temperature
  beacon_data[5] = (temp >> 8);                       //
  beacon_data[6] = ((bootcount & 0xFF000000) >> 24);  // Advertising PDU count
  beacon_data[7] = ((bootcount & 0xFF0000) >> 16);    //
  beacon_data[8] = ((bootcount & 0xFF00) >> 8);       //
  beacon_data[9] = (bootcount & 0xFF);                //
  beacon_data[10] = ((tmil & 0xFF000000) >> 24);      // Time since power-on or reboot
  beacon_data[11] = ((tmil & 0xFF0000) >> 16);        //
  beacon_data[12] = ((tmil & 0xFF00) >> 8);           //
  beacon_data[13] = (tmil & 0xFF);                    //

  // oAdvertisementData.setServiceData(BLEUUID(beconUUID), std::string(beacon_data, 14));

  // pAdvertising->setScanResponseData(oAdvertisementData);


  BLEBeacon oBeacon = BLEBeacon();
  oBeacon.setManufacturerId(0x4C00);  // fake Apple 0x004C LSB (ENDIAN_CHANGE_U16!)
  oBeacon.setProximityUUID(BLEUUID(BEACON_UUID));
  oBeacon.setMajor((bootcount & 0xFFFF0000) >> 16);
  oBeacon.setMinor(bootcount & 0xFFFF);
  BLEAdvertisementData oAdvertisementData = BLEAdvertisementData();
  BLEAdvertisementData oScanResponseData = BLEAdvertisementData();

  oAdvertisementData.setFlags(0x06);  // BR_EDR_NOT_SUPPORTED 0x04
  oAdvertisementData.setCompleteServices(BLEUUID(beconUUID));
  std::string strServiceData = "";

  strServiceData += (char)26;    // Len
  strServiceData += (char)0xFF;  // Type
  strServiceData += oBeacon.getData();
  oAdvertisementData.addData(strServiceData);

  oAdvertisementData.setServiceData(BLEUUID(beconUUID), std::string(beacon_data, 14));

  // pAdvertising->setAdvertisementData(oAdvertisementData);
  pAdvertising->setScanResponseData(oAdvertisementData);
  // pAdvertising->setAdvertisementData(oAdvertisementData);
  // pAdvertising->setScanResponseData(oScanResponseData);
}

void setup() {

  Serial.begin(115200);
  gettimeofday(&now, NULL);
  Serial.printf("start ESP32 %d\n", bootcount++);
  Serial.printf("deep sleep (%lds since last reset, %lds since last boot)\n", now.tv_sec, now.tv_sec - last);
  last = now.tv_sec;



  pixels.begin();  // This initializes the NeoPixel library.
  pixels.setBrightness(30);
  if (bootcount % 3 == 0)
    pixels.setPixelColor(0, pixels.Color(0, 0, 255));  // maarten
  if (bootcount % 3 == 1)
    pixels.setPixelColor(0, pixels.Color(0, 255, 0));  // maarten
  if (bootcount % 3 == 2)
    pixels.setPixelColor(0, pixels.Color(255, 0, 0));  // maarten
  pixels.show();


  // Create the BLE Device
  BLEDevice::init("ESP32 as iBeacon");
  // // Create the BLE Server
  // BLEServer *pServer = BLEDevice::createServer();  // <-- no longer required to instantiate BLEServer, less flash and ram usage
  // pAdvertising = BLEDevice::getAdvertising();
  // BLEDevice::startAdvertising();
  // setBeacon();
  // // Start advertising
  // pAdvertising->start();
  // Serial.println("Advertizing started...");

  // Create the BLE Server
  BLEServer *pServer = BLEDevice::createServer();

  pAdvertising = pServer->getAdvertising();

  setBeacon();
  // Start advertising
  pAdvertising->start();
  delay(10000);
  pAdvertising->stop();
  Serial.printf("enter deep sleep\n");
  esp_deep_sleep(1000000LL * GPIO_DEEP_SLEEP_DURATION);
  Serial.printf("in deep sleep\n");
}

void loop() {
}