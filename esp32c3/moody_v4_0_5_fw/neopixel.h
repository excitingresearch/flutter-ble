
#include <Adafruit_NeoPixel.h>


// When we setup the NeoPixel library, we tell it how many pixels, and which pin to use to send signals.
// Note that for older NeoPixel strips you might need to change the third parameter--see the strandtest
Adafruit_NeoPixel pixels = Adafruit_NeoPixel(1, NEOPIXEL_PIN, NEO_GRB + NEO_KHZ800);

void setup_neopixel() {


  pixels.begin();  // This initializes the NeoPixel library.
  pixels.setBrightness(30);
  if (bootCount % 3 == 0)
    pixels.setPixelColor(0, pixels.Color(0, 0, 255));  // maarten
  if (bootCount % 3 == 1)
    pixels.setPixelColor(0, pixels.Color(0, 255, 0));  // maarten
  if (bootCount % 3 == 2)
    pixels.setPixelColor(0, pixels.Color(255, 0, 0));  // maarten
  pixels.show();

}