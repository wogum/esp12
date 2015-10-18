# ESP12
ESP8266 NodeMCU mini WiFi module ESP-12 as data logger with BME280 temperature, humidity and pressure sensor and DS3231 RTC with 24C32 EEPPROM

### Modules:
- ESP12 mini WiFi module with ESP8266 SoC
- DS3231 precision RTC with 24C32 EEPROM
- BME280 temperature, humidity and pressure sensor

### Connections:
- GPIO4  - I2C SCL
- GPIO5  - I2C SDA
- GPIO13 - I2C and modules Vcc (to save battery power during deep sleep)
- GPIO12 - +LED - additional signalling LED with 1K resistor
- GPIO14 - -LED
- GPIO16 to RST - for deep sleep wakeup


