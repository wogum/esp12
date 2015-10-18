-- Nodemcu ESP8266 NTP implementation
-- LICENCE: http://opensource.org/licenses/MIT
-- based on https://github.com/annejan/nodemcu-lua-watch/blob/master/ntp.lua
-- 2015-06-12 WG
--
-- Example:
--   dofile("ntp.lua").sync(function(utc) _start=utc-tmr.time() end)
-- This module uses NodeMCU timer 2 in :sync()
local M
do
-- globals
if _cfg == nil then _cfg = { } end
if _cfg["tz"] == nil then _cfg["tz"] = 1 end					-- local timezone in hours
if _cfg["ntpserver"] == nil then _cfg["ntpserver"] = "153.19.250.123" end	-- IP address of NTP server
if _start == nil then _start = 0 end						-- unix timestamp of ESP start (UTC)
-- locals
local sk = nil

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

-- get date & time
-- Return: h, n, s, y, m, d, w
local function get()
    return unix2date(tmr.time() + _start + _cfg["tz"]*3600)
end

-- set RTC time from date
local function set(h,n,s,y,m,d,w)
    _start = date2unix(h,n,s,y,m,d,w) - tmr.time() - _cfg["tz"]*3600
end

-- RTC time string
local function time()
    local t, h, m, s
    t = tmr.time() + _start + _cfg["tz"]*3600
    h = t % 86400 / 3600
    m = t % 3600 / 60
    s = t % 60
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
    return tmr.time() + _start
end

-- set NodeMCU start time from NTP server
local function sync(callback, srv)
    if wifi.sta.status() ~= 5 then
	tmr.alarm(2, 3000, 0, sync)
	return
    end
    if srv == nil then srv = _cfg["ntpserver"] end
    local request=string.char(227, 0, 6, 236, 0,0,0,0,0,0,0,0, 49, 78, 49, 52, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    sk=net.createConnection(net.UDP, 0)
    sk:on("receive", function(sck, payload)
	local hw, lw, utc
	sck:close()
	hw = payload:byte(41) * 256 + payload:byte(42)
	lw = payload:byte(43) * 256 + payload:byte(44)
	utc = hw * 65536 + lw - 1104494400 - 1104494400
	if utc > 1420000000 then
	    _start = utc - tmr.time()
	    if callback ~= nil then callback(utc) end
	end
	sk:close()
    end)
    sk:connect(123, srv)
    sk:send(request)
    tmr.alarm(2, 3000, 0, function() if sk ~= nil then sk:close() sk=nil end end)
end

-- export functions
M = { time = time, date = date, timestamp = timestamp, get = get, set = set, sync = sync }
end
return M