

#include <WiFi.h>

const char *target_ssid = "moody-admin";  // Replace with your target SSID
const char *target_pw = "moody-pw";       // Replace with your target SSID


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

    while (WiFi.status() != WL_CONNECTED) {
      delay(500);
      debugPrint(".");
    }
    debugPrintln("\nWiFi connected!");
    debugPrintln("IP address: ");
    debugPrintln(WiFi.localIP());
  } else {
    debugPrintln("Target network not found. Turning WiFi off.");
    WiFi.mode(WIFI_OFF);
  }
}