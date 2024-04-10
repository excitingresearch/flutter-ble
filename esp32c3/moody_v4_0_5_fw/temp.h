#include "esp_system.h"

const int button = 0;         //gpio to use to trigger delay
const int wdtTimeout = 1000;  //time in ms to trigger the watchdog
hw_timer_t *timer = NULL;

void ARDUINO_ISR_ATTR resetModule() {
  ets_printf("reboot\n");
  esp_restart();
}



// Circular buffer variables
float temperatureBuffer[MAX_BUFFER_SIZE];
int bufferIndex = 0;
float tempSum = 0;
int rc = 0;
float tempMin = 99;  // Initialize with highest possible float
float tempMax = 0;   // Initialize with lowest possible float
byte rgb_r = 0;
byte rgb_g = 0;
byte rgb_b = 0;

void setup_watchdog() {
  timer = timerBegin(0, 80, true);                   //timer 0, div 80
  timerAttachInterrupt(timer, &resetModule, true);   //attach callback
  timerAlarmWrite(timer, wdtTimeout * 1000, false);  //set time in us
  timerAlarmEnable(timer);
}

void loop_temp() {

  if (high_time_prev_trig != 0 && high_time_trig != 0 && low_time_trig != 0 && last_prev_val_parsed != high_time_prev_trig) {
    last_prev_val_parsed = high_time_prev_trig;
    int t = high_time_trig - high_time_prev_trig;
    int h = low_time_trig - high_time_prev_trig;
    float d = h / float(t);
    if (d > 1)
      d -= 1;
    if (d < 1) {
      float temperature = 212.77 * d - 68.085;
      t_avg += temperature;
      t_c++;
    }
  }


  if (millis() - lastPrint > 500) {
    timerWrite(timer, 0);  //reset timer (feed watchdog)

    float temperature = t_avg / float(t_c);



    if (millis() < 2000 || temperature < 15 || temperature > 40) {
      t_avg = 0.0;
      t_c = 0;
      lastPrint = millis();
      return;
    }

    if (rc <= current_buffer_size)
      rc++;


    if (tempMin == temperatureBuffer[bufferIndex]) {
      tempMin = 99;
      for (int i = 0; i < current_buffer_size; i++) {
        if (i != bufferIndex && temperatureBuffer[i] < tempMin) {
          tempMin = temperatureBuffer[i];
          debugPrintln("new Min");
        }
      }
    } else if (tempMax == temperatureBuffer[bufferIndex]) {
      tempMax = 0;
      for (int i = 0; i < current_buffer_size; i++) {
        if (i != bufferIndex && temperatureBuffer[i] < tempMax) {
          tempMax = temperatureBuffer[i];
          debugPrintln("new Max");
        }
      }
    }

    // Update sum, min, max
    tempSum -= temperatureBuffer[bufferIndex];  // Remove the oldest value
    tempSum += temperature;
    // Add new value to the buffer
    temperatureBuffer[bufferIndex] = temperature;
    bufferIndex = (bufferIndex + 1) % current_buffer_size;  // Increment with wrap-around

    if (temperature < tempMin) {
      tempMin = temperature;
    }
    if (temperature > tempMax) {
      tempMax = temperature;
    }

    // debugPrintln("Temp: " + String(temperature));
    uint32_t Vbatt = 0;
    for (int i = 0; i < 16; i++) {
      Vbatt = Vbatt + analogReadMilliVolts(BATTERY_PIN);  // ADC with correction
    }
    float Vbattf = 2 * Vbatt / 16 / 1000.0;  // attenuation ratio 1/2, mV --> V
    // Calculate and print statistics
    float tempAvg = tempSum / min(current_buffer_size, (rc));
    debugPrint("t: ");
    debugPrint(millis() / 1000);
    debugPrint("s BAT: ");
    Serial.print(Vbattf, 3);
    debugPrint("V Cur: ");
    debugPrint(temperature);
    debugPrint("°C Min: ");
    debugPrint(tempMin);
    debugPrint(", Max: ");
    debugPrint(tempMax);
    debugPrint(", Avg: ");
    debugPrint(tempAvg);
    debugPrint(", Range LOW - AVG: ");
    debugPrint(tempAvg - tempMin);
    debugPrint(", Range AVG - HIGH: ");
    debugPrint(tempMax - tempAvg);
    float d_from_avg = abs(temperature - tempAvg);
    float p = 0.0;
    if (temperature > tempAvg) {
      float range = tempMax - tempAvg;
      p = d_from_avg / range;
    } else {
      float range = tempAvg - tempMin;
      p = d_from_avg / range;
    }

    debugPrint(", p: ");
    debugPrint(p);


    debugPrint(", c1: ");
    debugPrint(p * 255);
    debugPrint(", c2: ");
    debugPrint(255 - (p * 255));
    if (temperature > tempAvg) {
      rgb_r = p * 255;
      rgb_g = 255 - (p * 255);
      rgb_b = 0;
    } else {
      rgb_r = 0;
      rgb_g = 255 - (p * 255);
      rgb_b = p * 255;
    }

    current_rgb[0] = target_rgb[0];
    current_rgb[1] = target_rgb[1];
    current_rgb[2] = target_rgb[2];

    target_rgb[0] = rgb_r;
    target_rgb[1] = rgb_g;
    target_rgb[2] = rgb_b;

    target_rgb_start = millis();
    last_rgb_loop = 0;

    debugPrint(", R: ");
    debugPrint(rgb_r);
    debugPrint(", G: ");
    debugPrint(rgb_g);
    debugPrint(", B: ");
    debugPrintln(rgb_b);
    ble_send(String(temperature) + "|" + String(rgb_r) + "," + String(rgb_g) + "," + String(rgb_b) + "|" + String(round(Vbattf * 1000) / 1000.0));

    t_avg = 0.0;
    t_c = 0;
    lastPrint = millis();
  }
}
