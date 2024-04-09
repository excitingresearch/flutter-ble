


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
      //   debugPrint("t: ");
      //   debugPrint(t);
      //   debugPrint(" h: ");
      //   debugPrint(h);
      //   debugPrint(" h/t: ");
      //   debugPrint(d);
      //   debugPrint(" temperature: ");
      //   debugPrintln(temperature);
      t_avg += temperature;
      t_c++;
    }
  }


  if (millis() - lastPrint > 500) {
    float temperature = t_avg / float(t_c);



    if (millis() < 2000 || temperature < 15 || temperature > 40) {
      t_avg = 0.0;
      t_c = 0;
      lastPrint = millis();
      return;
    }

    if (rc <= current_buffer_size)
      rc++;

    // if (temperature < 20.0) {
    //   pixels.setPixelColor(0, pixels.Color(0, 0, 255));
    // } else if (temperature < 25.0) {
    //   pixels.setPixelColor(0, pixels.Color(0, 255, 0));
    // } else {
    //   pixels.setPixelColor(0, pixels.Color(255, 0, 0));
    // }

    // pixels.show();




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
    debugPrint("V Min: ");
    debugPrint(temperature);
    debugPrint(" Min: ");
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
      // pixels.setPixelColor(0, pixels.Color(p * 255, 255 - (p * 255), 0));
      rgb_r = p * 255;
      rgb_g = 255 - (p * 255);
      rgb_b = 0;
    } else {
      // pixels.setPixelColor(0, pixels.Color(0, 255 - (p * 255), p * 255));
      rgb_r = 0;
      rgb_g = 255 - (p * 255);
      rgb_b = p * 255;
    }

    pixels.setPixelColor(0, pixels.Color(rgb_r, rgb_g, rgb_b));

    pixels.show();

    debugPrint(", R: ");
    debugPrint(rgb_r);
    debugPrint(", G: ");
    debugPrint(rgb_g);
    debugPrint(", B: ");
    debugPrintln(rgb_b);
    ble_send(String(temperature) + "|" + String(rgb_r) + "," + String(rgb_g) + "," + String(rgb_b) + "|" + String(round(Vbattf*1000)/1000.0));

    t_avg = 0.0;
    t_c = 0;
    lastPrint = millis();
  }
}
