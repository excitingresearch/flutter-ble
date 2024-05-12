#include <WiFi.h>
#include <ESPmDNS.h>
#include <WiFiUdp.h>
#include <ArduinoOTA.h>

bool ota_enabled = false;






void setup_ota() {
  // Serial.begin(115200);
  // Serial.println("Booting");
  // WiFi.mode(WIFI_STA);
  // WiFi.begin(ssid, password);


  // Port defaults to 3232
  // ArduinoOTA.setPort(3232);
  // check_device_name();
  // Hostname defaults to esp3232-[MAC]
  ArduinoOTA.setHostname(BLE_device_name.c_str());

  // No authentication by default
  ArduinoOTA.setPassword("m00dy");

  // Password can be set with it's md5 value as well
  // MD5(admin) = 21232f297a57a5a743894a0e4a801fc3
  // ArduinoOTA.setPasswordHash("21232f297a57a5a743894a0e4a801fc3");

  ArduinoOTA
    .onStart([]() {
      String type;
      if (ArduinoOTA.getCommand() == U_FLASH)
        type = "sketch";
      else  // U_SPIFFS
        type = "filesystem";

      // NOTE: if updating SPIFFS this would be the place to unmount SPIFFS using SPIFFS.end()
      Serial.println("Start updating " + type);
    })
    .onEnd([]() {
      Serial.println("\nEnd");
    })
    .onProgress([](unsigned int progress, unsigned int total) {
      Serial.printf("Progress: %u%%\r", (progress / (total / 100)));
    })
    .onError([](ota_error_t error) {
      Serial.printf("Error[%u]: ", error);
      if (error == OTA_AUTH_ERROR) Serial.println("Auth Failed");
      else if (error == OTA_BEGIN_ERROR) Serial.println("Begin Failed");
      else if (error == OTA_CONNECT_ERROR) Serial.println("Connect Failed");
      else if (error == OTA_RECEIVE_ERROR) Serial.println("Receive Failed");
      else if (error == OTA_END_ERROR) Serial.println("End Failed");
    });

  ArduinoOTA.begin();
  ota_enabled = true;
  Serial.println("OTA Ready");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
}

void scan_and_try_connect() {

  // Start WiFi scan
  debugPrintln("Scanning for WiFi networks...");
  int n = WiFi.scanNetworks();

  bool found = false;
  if (n > 0) {
    for (int i = 0; i < n; ++i) {
      if (String(WiFi.SSID(i)) == target_ssid) {
        found = true;
        break;
      }
    }
  }

  if (found) {
    debugPrintln("Target network found! Connecting...");
    // Add your WiFi credentials if not saved previously
    WiFi.begin(target_ssid, target_pw);
    unsigned long wifi_connect_start = millis();
    bool led_on = true;

    while (WiFi.status() != WL_CONNECTED && millis() - wifi_connect_start < 7500) {
      led_on = !led_on;
      pixels.setBrightness(led_on * MAX_BRIGHTNESS);
      pixels.show();
      delay(500);
      debugPrint(".");
    }

    pixels.setBrightness(MAX_BRIGHTNESS);
    pixels.show();
    if (WiFi.status() != WL_CONNECTED) {
      debugPrintln("WiFi Connection Failed! ");  // Rebooting... ?
      delay(1000);
      WiFi.disconnect(true, false);
      WiFi.mode(WIFI_OFF);
      // ESP.restart();
    } else {

      debugPrintln("\nWiFi connected!");
      debugPrintln("IP address: ");
      debugPrintln(WiFi.localIP());
      setup_ota();
    }


  } else {
    debugPrintln("Target network not found. Turning WiFi off.");
    WiFi.mode(WIFI_OFF);
  }
}

void loop_ota() {
  if (ota_enabled)
    ArduinoOTA.handle();
}