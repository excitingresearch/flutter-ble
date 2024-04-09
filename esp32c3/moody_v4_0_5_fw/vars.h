#ifdef DEBUG_MODE
#define debugPrint(x) Serial.print(x)
#define debugPrintln(x) Serial.println(x)
#else
#define debugPrint(x) 
#define debugPrintln(x)
#endif


int current_buffer_size = 120;


unsigned long last_prev_val_parsed = 0;
float t_avg = 0.0;
int t_c = 0;


RTC_DATA_ATTR int bootCount = 0;

unsigned long lastPrint = 0;
volatile unsigned long high_time_trig = 0;
volatile unsigned long high_time_prev_trig = 0;
volatile unsigned long low_time_trig = 0;
volatile unsigned long high_time = 0;
volatile unsigned long last_high_time = 0;
volatile unsigned long low_time = 0;
volatile unsigned long high_time_start = 0;
volatile unsigned long low_time_start = 0;
volatile long has_interrupted_f = 0;
volatile long has_interrupted_r = 0;
volatile int c = 0;
volatile int T = 0.0;
volatile float d = 0.0;
volatile int ttteeempp = 0;