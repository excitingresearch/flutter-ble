
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
// #include <EEPROM.h>

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;
uint8_t txValue = 0;

// See the following for generating UUIDs:
// https://www.uuidgenerator.net/

#define SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"  // UART service UUID
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"


void ble_send(String msg) {
  if (deviceConnected) {
    pTxCharacteristic->setValue(msg.c_str());
    pTxCharacteristic->notify();
    debugPrintln("notify " + msg);
    delay(10);  // bluetooth stack will go into congestion, if too many packets are sent
  }
}




class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    deviceConnected = true;
  };

  void onDisconnect(BLEServer *pServer) {
    deviceConnected = false;
  }
};

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    std::string rxValue = pCharacteristic->getValue();

    if (rxValue.length() > 0) {
      debugPrintln("*********");
      debugPrint("Received Value: ");
      for (int i = 0; i < rxValue.length(); i++)
        debugPrint(rxValue[i]);

      debugPrintln();
      debugPrintln("*********");
    }
  }
};


// String loadOrStoreName() {
//   String name;
//   const int addressStart = 0;  // Starting address in EEPROM
//   const int nameLength = 10;   // Length of the name

//   EEPROM.begin(512);  // Adjust size as needed
//   // Try to load the name from EEPROM
//   bool hasName = true;
//   for (int i = 0; i < nameLength; i++) {
//     char storedChar = EEPROM.read(addressStart + i);
//     if (storedChar == 0 || storedChar == 255) {
//       hasName = false;
//       break;
//     }
//     name += storedChar;
//   }

//   // If the name was not in EEPROM, store it
//   if (!hasName) {

//     // BLEDevice::init("moody-flashed");
//     String address = WiFi.macAddress().c_str();
//     //BLEDevice::getAddress().toString().c_str();
//     address.toUpperCase();
//     debugPrintln("NO STORED NAME");
//     debugPrintln(address);

//     String name = "Moody ";
//     name += address[address.length() - 5];
//     name += address[address.length() - 4];
//     name += address[address.length() - 2];
//     name += address[address.length() - 1];
//     // name = "";
//     // name += address[address.length() - 5];
//     // name += address[address.length() - 4];
//     // name += address[address.length() - 2];
//     // name += address[address.length() - 1];

//     // Store the name
//     for (int i = 0; i < nameLength; i++) {
//       EEPROM.write(addressStart + i, name[i]);
//     }
//     EEPROM.commit();
//     delay(10);
//     // EEPROM.end();
//     // delay(10);
//     // ESP.restart();
//   }
//   EEPROM.end();
//   delay(10);
//   return name;
// }


/** MAIN **/
void setup_ble() {
  // Serial.begin(115200);
  // check_device_name();
  // delay(500);
  BLEDevice::init(BLE_device_name.c_str());
  debugPrintln("ble initted");

  // Create the BLE Device
  // BLEDevice::init(BleDeviceName);

  // Get the MAC address
  String address = BLEDevice::getAddress().toString().c_str();
  // name = "Squeezi-";
  // name += address[address.length() - 5];
  // name += address[address.length() - 4];
  // name += address[address.length() - 2];
  // name += address[address.length() - 1];

  // Print the MAC address
  debugPrint("BLE MAC Address: ");
  debugPrintln(address);

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic
  pTxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_TX,
    BLECharacteristic::PROPERTY_NOTIFY);

  pTxCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic *pRxCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_RX,
    BLECharacteristic::PROPERTY_WRITE);

  pRxCharacteristic->setCallbacks(new MyCallbacks());

  // Start the service
  pService->start();

  // Start advertising
  pServer->getAdvertising()->addServiceUUID(pService->getUUID());
  pServer->getAdvertising()->start();
  debugPrintln("Waiting a client connection to notify...");
}

void loop_ble() {


  // disconnecting
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);                   // give the bluetooth stack the chance to get things ready
    pServer->startAdvertising();  // restart advertising
    debugPrintln("start advertising");
    oldDeviceConnected = deviceConnected;
  }
  // connecting
  if (deviceConnected && !oldDeviceConnected) {
    // do stuff here on connecting
    oldDeviceConnected = deviceConnected;
  }
}