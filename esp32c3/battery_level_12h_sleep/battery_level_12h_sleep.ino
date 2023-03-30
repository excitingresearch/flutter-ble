#include <chrono>
static constexpr auto DEEP_SLEEP_TIME = std::chrono::hours{ 12 };

void setup() {
  Serial.begin(115200);
  pinMode(A3, INPUT);  // ADC
}

void loop() {
  uint32_t Vbatt = 0;
  for (int i = 0; i < 16; i++) {
    Vbatt = Vbatt + analogReadMilliVolts(A3);  // ADC with correction
  }
  float Vbattf = 2 * Vbatt / 16 / 1000.0;  // attenuation ratio 1/2, mV --> V
  Serial.println(Vbattf, 3);
  if (Vbattf <= 3.2) {
    Serial.println("going to sleep");
    delay(100);
    // ...
    // ...
    esp_sleep_enable_timer_wakeup(
      std::chrono::duration_cast<std::chrono::microseconds>(
        DEEP_SLEEP_TIME)
        .count());
    delay(10);
    esp_deep_sleep_start();
  }

  delay(1000);
}