
#include <Adafruit_NeoPixel.h>

const byte MAX_BRIGHTNESS = 30;

// When we setup the NeoPixel library, we tell it how many pixels, and which pin to use to send signals.
// Note that for older NeoPixel strips you might need to change the third parameter--see the strandtest
Adafruit_NeoPixel pixels = Adafruit_NeoPixel(1, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);


void powerOnSequence() {
  pixels.setBrightness(0);
  const int numSteps = 30;
  const int duration = 700;

  for (int i = 0; i <= numSteps; i++) {
    uint8_t r = map(i, 0, numSteps, 0, 255);                 // Red fades in
    uint8_t g = map(i, numSteps / 3, numSteps, 255, 0);      // Green fades in, then out
    uint8_t b = map(i, 2 * numSteps / 3, numSteps, 255, 0);  // Blue fades in, then out

    pixels.setPixelColor(0, r, g, b);
    pixels.setBrightness(i * MAX_BRIGHTNESS / numSteps);
    pixels.show();
    delay(duration / numSteps);
  }
}

void powerOffSequence() {
  const int numSteps = 30;
  const int duration = 700;

  for (int i = numSteps; i >= 0; i--) {
    uint8_t r = map(i, 0, numSteps, 0, 255);                 // Red fades in
    uint8_t g = map(i, numSteps / 3, numSteps, 255, 0);      // Green fades in, then out
    uint8_t b = map(i, 2 * numSteps / 3, numSteps, 255, 0);  // Blue fades in, then out

    pixels.setPixelColor(0, r, g, b);
    pixels.setBrightness(i * MAX_BRIGHTNESS / numSteps);
    pixels.show();
    delay(duration / numSteps);
  }
}

void neopixel_loop() {
  unsigned long n = millis();
  int t_d = n - last_rgb_loop;

  if (t_d >= 10) {
    last_rgb_loop = n;
    int t_s = n - target_rgb_start;
    float t_p = t_s / 500.0;

    int d_rgb[] = { current_rgb[0] + t_p * (target_rgb[0] - current_rgb[0]), current_rgb[1] + t_p * (target_rgb[1] - current_rgb[1]), current_rgb[2] + t_p * (target_rgb[2] - current_rgb[2]) };
    pixels.setPixelColor(0, d_rgb[0], d_rgb[1], d_rgb[2]);
    pixels.setBrightness(MAX_BRIGHTNESS);
    pixels.show();


    // debugPrint("OVERGANG: ");
    // debugPrint(t_p);
    // debugPrint("% from");
    // debugPrint(current_rgb[0]);
    // debugPrint(", ");
    // debugPrint(current_rgb[1]);
    // debugPrint(", ");
    // debugPrint(current_rgb[2]);
    // debugPrint("  to   ");
    // debugPrint(target_rgb[0]);
    // debugPrint(", ");
    // debugPrint(target_rgb[1]);
    // debugPrint(", ");
    // debugPrint(target_rgb[2]);
    // debugPrint("  makes   ");
    // debugPrint(d_rgb[0]);
    // debugPrint(", ");
    // debugPrint(d_rgb[1]);
    // debugPrint(", ");
    // debugPrintln(d_rgb[2]);
  }
}

void setup_neopixel() {
  pixels.begin();  // This initializes the NeoPixel library.
  powerOnSequence();
  // pixels.setBrightness(30);
  // if (bootCount % 3 == 0)
  //   pixels.setPixelColor(0, pixels.Color(0, 0, 255));  // maarten
  // if (bootCount % 3 == 1)
  //   pixels.setPixelColor(0, pixels.Color(0, 255, 0));  // maarten
  // if (bootCount % 3 == 2)
  //   pixels.setPixelColor(0, pixels.Color(255, 0, 0));  // maarten
  // pixels.show();
}