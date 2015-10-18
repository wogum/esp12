-- periodic data recording for BME280
-- 2015.10.16 WG

-- globals
if _temp == nil then _temp = { } end
if _ee == nil then _ee = dofile("ee.lc").find() end

--recordData = nil
function recordData()
    local d
    pwm.setduty(6, 500)
    if _debug then print("#record", dofile("ds32.lc").time()) end
    -- write data to EEPROM
    dofile("ee.lc").chunkWrite(_ee, _temp[1], _temp[2], _temp[3], dofile("ds32.lc").get())
    _ee = (_ee + 8) % _eesize
    -- record temp to monitoring station
    dofile("http.lc").post(_ee-768)
    -- wait time
    pwm.setduty(6, 10)
    local s = dofile("ds32.lc").timestamp()
    s = 60 * (_cfg["rec"] - s % 3600 / 60 % _cfg["rec"]) - 15
    tmr.alarm(1, s*1000, 0, recordStart)
    if _cfg["slp"] > 0 or wifi.sta.status() ~= 5 then
	tmr.alarm(1, 10000, 0, function() node.dsleep(s*1000000) end)
    end
end

--recordStart = nil
function recordStart()
    pwm.setduty(6, 1000)
    if _debug then print("#start", dofile("ds32.lc").time()) end
    local t, p, h = dofile("bme280.lc").read()
    _temp[1] = t
    _addr[1] = "BME280-" .. node.chipid()
    _temp[2] = p
    _addr[2] = "BME280-" .. node.chipid()
    _temp[3] = h
    _addr[3] = "BME280-" .. node.chipid()
    pwm.setduty(6, 10)
    if _debug then print("#start", cjson.encode(_temp)) end
    -- time to next record date
    local s = dofile("ds32.lc").timestamp()
    s = 60 * (_cfg["rec"] - s % 3600 / 60 % _cfg["rec"]) - s % 60
    tmr.alarm(1, s*1000, 0, recordData)
    -- deep sleep to save power
    if s > 30 and ( _cfg["slp"] > 0 or wifi.sta.status() ~= 5 ) then
	node.dsleep((s-29)*1000000)
    end
end

-- wait for synchronization 
tmr.alarm(1, 5000, 0, recordStart)
-- led
pwm.setclock(6, 1)