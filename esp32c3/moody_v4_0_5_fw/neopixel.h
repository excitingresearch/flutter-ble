
#include <Adafruit_NeoPixel.h>


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
    pixels.setBrightness(i * 255 / numSteps);
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
    pixels.setBrightness(i * 255 / numSteps);
    pixels.show();
    delay(duration / numSteps);
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