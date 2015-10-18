-- config
dofile("config.lc").load()
-- WiFi
wifi.setmode(wifi.STATION)
wifi.sleeptype(wifi.LIGHT_SLEEP)
wifi.sta.config(_cfg["ssid"], _cfg["pwd"], 1)
wifi.sta.connect()
-- power ext on GPIO13
gpio.mode(7, gpio.OUTPUT)
gpio.write(7, gpio.HIGH)
-- led on GPIO12 GND GPIO14
gpio.mode(5, gpio.OUTPUT)
gpio.write(5, gpio.LOW)
pwm.setup(6, 5, 10)
pwm.start(6)

-- globals
_ver = "ESP-12-151016"
_eesize = 4096
_ee = 0
_temp = { }
_addr = { }
if cfg == nil then cfg = { } end
if _cfg["rec"] == nil then _cfg["rec"] = 15 end
if _cfg["tz"] == nil then _cfg["tz"] = 2 end

-- modules
-- start RTC DS3231 time synchronization
dofile("ds32.lc").sync()
-- find first free EEPROM address
_ee = 0
_ee = dofile("ee.lc").find()

-- start
dofile("bme280.lc").read()
-- start DS18B20 temperature conversion
--dofile("ds18.lc").temp(function(r)
--    _temp = { }
--    _addr = { }
--    for k, v in pairs(r) do
--	_temp[1] = v
--	_addr[1] = k
--	break
--    end
--end)

-- start www server and periodic record
tmr.alarm(4, 2000, 0, function()
    dofile("www.lc")
    dofile("cron.lc")
end)
