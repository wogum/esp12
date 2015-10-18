-- DS3231 (DS1307) I2C RTC
-- Licence: http://opensource.org/licenses/MIT
-- 2015-07-08 WG
--
-- Example:
-- h,n,s,Y,M,D,W = dofile("ds32.lua").get()
local M
do
-- globals
if _cfg == nil then _cfg = { } end
if _cfg["tz"] == nil then _cfg["tz"] = 1 end		-- local timezone in hours
if _start == nil then _start = 0 end	-- unix timestamp of ESP start (UTC)
-- i2c pins
local sda = 2
local scl = 1
-- i2c addr
local adr = 0x68

--
local function bin2bcd(x)
    return x/10*16+x%10
end

--
local function bcd2bin(x)
    return x/16*10+x%16
end

-- convert date&time to unix epoch time
local function date2unix(h, n, s, y, m, d, w)
    local a, jd
    a = (14 - m) / 12
    y = y + 4800 - a
    m = m + 12*a - 3
    jd = d + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    return (jd - 2440588)*86400 + h*3600 + n*60 +s
end

-- convert unix epoch time to date&time
-- return h, m, s, Y, M, D, W (1-mon, 7-sun)
local function unix2date(t)
    local jd, f, e, h, y, m, d
    jd = t / 86400 + 2440588
    f = jd + 1401 + (((4 * jd + 274277) / 146097) * 3) / 4 - 38
    e = 4 * f + 3
    h = 5 * ((e % 1461) / 4) + 2
    d = (h % 153) / 5 + 1
    m = (h / 153 + 2) % 12 + 1
    y = e / 1461 - 4716 + (14 - m) / 12
    return t%86400/3600, t%3600/60, t%60, y, m, d, jd%7+1
end

-- get RTC time and date 
-- return: h m s Y M D W (1-mon, 7-sun)
local function get()
    local c
    i2c.setup(0, sda, scl, i2c.SLOW)
    i2c.start(0)
    i2c.address(0, adr, i2c.TRANSMITTER)
    i2c.write(0, 0x00)
    i2c.stop(0)
    i2c.start(0)
    i2c.address(0, adr, i2c.RECEIVER)
    c=i2c.read(0, 7)
    i2c.stop(0)
    return bcd2bin(c:byte(3)), bcd2bin(c:byte(2)), bcd2bin(c:byte(1)),
	2000+bcd2bin(c:byte(7)), bcd2bin(c:byte(6)), bcd2bin(c:byte(5)),
	bcd2bin(c:byte(4))
end

-- set RTC time and date
local function set(h,n,s,y,m,d,w)
    i2c.setup(0, sda, scl, i2c.SLOW)
    i2c.start(0)
    i2c.address(0, adr, i2c.TRANSMITTER)
    i2c.write(0, 0x00)
    i2c.write(0, bin2bcd(s))
    i2c.write(0, bin2bcd(n))
    i2c.write(0, bin2bcd(h))
    if w ~= nil then
	i2c.write(0, w)
	i2c.write(0, bin2bcd(d))
	i2c.write(0, bin2bcd(m))
	i2c.write(0, bin2bcd(y%100))
	end
    i2c.stop(0)
end

-- get RTC internal temp in miliC
local function temp()
    local c,t
    i2c.setup(0, sda, scl, i2c.SLOW)
    i2c.start(0)
    i2c.address(0, adr, i2c.TRANSMITTER)
    i2c.write(0, 0x11)
    i2c.stop(0)
    i2c.start(0)
    i2c.address(0, adr, i2c.RECEIVER)
    c = i2c.read(0, 2)
    i2c.stop(0)
    t = c:byte(1)
    if t > 127 then
	t = t - 256
    end
    return t * 1000 + c:byte(2) / 64 * 250
end

-- RTC time string
local function time()
    local h, m, s
    h, m, s = get()
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- RTC date string
local function date()
    local h, n, s, y, m, d
    h, n, s, y, m, d = get()
    return string.format("%d-%02d-%02d", y, m, d)
end

-- RTC unix epoch time
local function timestamp()
    return date2unix(get()) - _cfg["tz"] * 3600
end

-- set NodeMCU start time
local function sync()
    _start = date2unix(get()) - tmr.time() - _cfg["tz"] * 3600
end

-- export functions
M = { time = time, date = date, timestamp = timestamp, sync = sync, get = get, set = set, temp = temp }
end
return M