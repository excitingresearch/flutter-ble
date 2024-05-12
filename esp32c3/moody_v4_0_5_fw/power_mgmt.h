#include "esp32-hal-timer.h"

#define BUTTON_PIN_BITMASK 0x200000000  // 2^33 in hex



void IRAM_ATTR myInterruptFunctionFalling() {
  low_time_trig = micros();
}

void IRAM_ATTR myInterruptFunctionRising() {
  high_time_prev_trig = high_time_trig;
  high_time_trig = micros();
}


void IRAM_ATTR myInterruptFunction() {
  if (digitalRead(TEMP_PWM_PIN) == 0) {
    myInterruptFunctionFalling();
  } else {
    myInterruptFunctionRising();
  }
}


/*
Method to print the reason by which ESP32
has been awaken from sleep
*/
void print_wakeup_reason() {
  esp_sleep_wakeup_cause_t wakeup_reason;

  wakeup_reason = esp_sleep_get_wakeup_cause();

  switch (wakeup_reason) {
    case ESP_SLEEP_WAKEUP_EXT0: debugPrintln("Wakeup caused by external signal using RTC_IO"); break;
    case ESP_SLEEP_WAKEUP_EXT1: debugPrintln("Wakeup caused by external signal using RTC_CNTL"); break;
    case ESP_SLEEP_WAKEUP_TIMER: debugPrintln("Wakeup caused by timer"); break;
    case ESP_SLEEP_WAKEUP_TOUCHPAD: debugPrintln("Wakeup caused by touchpad"); break;
    case ESP_SLEEP_WAKEUP_ULP: debugPrintln("Wakeup caused by ULP program"); break;
    default:
      debugPrint("Wakeup was not caused by deep sleep: \n");
      debugPrintln(wakeup_reason);
      break;
  }
}

void check_sleep() {
  if (digitalRead(WAKE_UP_PIN) == 0) {
    delay(15); // debounce
    if (digitalRead(WAKE_UP_PIN) == 0) {
      //Go to sleep now
      debugPrintln("Going to sleep now");

      // pixels.setBrightness(0);
      // debugPrint("brightness: ");
      // debugPrintln(0);
      // pixels.show();
      // debugPrintln("Going to sleep now");
      // delay(150);
      // // timerAlarmEnable(timer);
      // // timerAlarmDisable(timer);
      // delay(100);
      // powerOffSequence();
      // debugPrintln("End going to sleep");
      // while (digitalRead(WAKE_UP_PIN) == 0) {
      //   delay(500);
      //   debugPrintln("sleeping");
      //   timerWrite(timer, 0);  //reset timer (feed watchdog)
      // }
      // timerWrite(timer, 0);  //reset timer (feed watchdog)

      // debugPrintln("wakeup");
      delay(50);
      esp_deep_sleep_start();
    }
  }
}


void loop_sleep() {
  check_sleep();
}

void setup_sleep() {

  delay(1000);  //Take some time to open up the Serial Monitor

  //Increment boot number and print it every reboot
  ++bootCount;
  debugPrintln("Boot number: " + String(bootCount));

  pinMode(WAKE_UP_PIN, INPUT_PULLUP);
  // Print the wakeup reason for ESP32
  print_wakeup_reason();

  /*
  First we configure the wake up source
  We set our ESP32 to wake up for an external trigger.
  There are two types for ESP32, ext0 and ext1 .
  ext0 uses RTC_IO to wakeup thus requires RTC peripherals
  to be on while ext1 uses RTC Controller so doesnt need
  peripherals to be powered on.
  Note that using internal pullups/pulldowns also requires
  RTC peripherals to be turned on.
  */
  // esp_sleep_enable_ext0_wakeup(GPIO_NUM_9, 1);  //1 = High, 0 = Low
  esp_deep_sleep_enable_gpio_wakeup(BIT(WAKE_UP_PIN), ESP_GPIO_WAKEUP_GPIO_HIGH);

  //If you were to use ext1, you would use it like
  //esp_sleep_enable_ext1_wakeup(BUTTON_PIN_BITMASK,ESP_EXT1_WAKEUP_ANY_HIGH);

  check_sleep();

  pinMode(TEMP_PWM_PIN, INPUT_PULLUP);  // Configure the pin as an input with internal pull-up resistor
  attachInterrupt(digitalPinToInterrupt(TEMP_PWM_PIN), myInterruptFunction, CHANGE);
}
