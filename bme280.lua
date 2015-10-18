------------------------------------------------------------------------------
-- BME280  module for ESP8266 int version
--
-- LICENCE: http://opensource.org/licenses/MIT
-- AUTHOR: WG 2015-10-16
--
-- Example:
-- t, p, h = dofile("bme280.lua").read()
------------------------------------------------------------------------------
local M
do
-- cache
local i2c, tmr = i2c, tmr
local sda = 2
local scl = 1
-- helpers
local function r8(reg)
    local r = { }
    i2c.start(0)
    i2c.address(0, 0x77, i2c.TRANSMITTER)
    i2c.write(0, reg)
    i2c.stop(0)
    i2c.start(0)
    i2c.address(0, 0x77, i2c.RECEIVER)
    r = i2c.read(0, 1)
    i2c.stop(0)
    return r:byte(1)
    end
local function w8(reg, val)
    i2c.start(0)
    i2c.address(0, 0x77, i2c.TRANSMITTER)
    i2c.write(0, reg)
    i2c.write(0, val)
    i2c.stop(0)
    end
local function r16u(reg)
    local r = { }
    i2c.start(0)
    i2c.address(0, 0x77, i2c.TRANSMITTER)
    i2c.write(0, reg)
    i2c.stop(0)
    i2c.start(0)
    i2c.address(0, 0x77, i2c.RECEIVER)
    r = i2c.read(0, 2)
    i2c.stop(0)
    return r:byte(1) + r:byte(2) * 256
    end
    --return r8(reg) + r8(reg + 1) * 256
    --end
local function r16(reg)
    local r = r16u(reg)
    if r > 32767 then r = r - 65536 end
    return r
    end
local function rRaw()
    local t, p, h
    local r = { }
    i2c.start(0)
    i2c.address(0, 0x77, i2c.TRANSMITTER)
    i2c.write(0, 0xF7)
    i2c.stop(0)
    i2c.start(0)
    i2c.address(0, 0x77, i2c.RECEIVER)
    r = i2c.read(0, 8)
    i2c.stop(0)
    p = r:byte(1) * 4096 + r:byte(2) * 16 + r:byte(3) / 16
    t = r:byte(4) * 4096 + r:byte(5) * 16 + r:byte(6) / 16
    h = r:byte(7) * 256 + r:byte(8)
    r = nil
    return t, p, h
    end

-- calibration data
local T1, T2, T3, P1, P2, P3, P4, P5, P6, P7, P8, P9, H1, H2, H3, H4, H5, H6
-- read t, p, h [mC, Pa, m%]
local function read()
    i2c.setup(0, sda, scl, i2c.SLOW)
    -- Initial setup
    w8(0xF2, 0x01)	-- H oversampling x1
    w8(0xF4, 0x27)	-- P oversampling x1, T oversampling x1, mode Normal
    w8(0xF5, 0xA8)	-- 1000ms, IIR 4, I2C
    -- Calibration coefficients
    T1 = r16u(0x88)
    T2 = r16(0x8A)
    T3 = r16(0x8C)
    P1 = r16u(0x8E)
    P2 = r16(0x90)
    P3 = r16(0x92)
    P4 = r16(0x94)
    P5 = r16(0x96)
    P6 = r16(0x98)
    P7 = r16(0x9A)
    P8 = r16(0x9C)
    P9 = r16(0x9E)
    H1 = r8(0xA1)
    H2 = r16(0xE1)
    H3 = r8(0xE3)
    H4 = (r8(0xE4) * 16) + (r8(0xE5) % 16)
    H5 = (r8(0xE6) * 16) + (r8(0xE5) / 16)
    H6 = r8(0xE7)

    -- Raw Data
    local t, p, h
    t, p, h = rRaw()

    -- Temperature 
    --print("T=",T1,T2,T3)
    --local t = r8(0xFA) * 4096 + r8(0xFB) * 16 + r8(0xFC) / 16
    --print("t",t)
    local v1 = ((t/8 - T1*2) * T2) / 2048
    local v2 = ((((t/16 - T1) * (t/16 - T1)) / 4096) * T3) / 16384
    local tfine = v1 + v2
    --print("tf",tfine)
    --t = (tfine * 5 + 128) / 256
    t = (tfine * 5 + 128) / 256
    t = 10 * t
    --print("t=",t)

    -- Pressure (32bit version)
    --print("P=",P1,P2,P3,P4,P5,P6,P7,P8,P9)
    --local p = r8(0xF7) * 4096 + r8(0xF8) * 16 + r8(0xF9) / 16
    --print("p",p)
    v1 = (tfine - 128000) / 2
    v2 = (((v1 / 4) * (v1 / 4)) / 2048) * P6
    v2 = v2 + v1 * P5 * 2
    v2 = v2 / 4 + P4 * 65536
    v1 = ((P3 * (((v1 / 4) * (v1 / 4)) / 8192)) / 8 + (P2 * v1) / 2) / 262144
    v1 = ((32768 + v1) * P1) / 32768
    p = ((1048576 - p) - (v2 / 4096)) * 3125;
    if v1 ~= 0 then
	p = (p / v1) * 2
    else
	p = 0
	end
    v1 = (P9 * (((p / 8) * (p / 8)) / 8192)) / 4096
    v2 = ((p / 4) * P8) / 8192
    p = p + (v1 + v2 + P7) / 16
    --print("p=",p)

    -- Humidity
    --print("H=",H1,H2,H3,H4,H5,H6)
    --local h = r8(0xFD) * 256 + r8(0xFE)
    --print("h",h)
    v1 = tfine - 76800
    v1 = ((h * 16384 - H4 * 1024 * 1024 - H5 * v1 + 16384) / 32768) * ((((((v1 * H6 / 1024) * (v1 * H3 / 2048) + 32768) / 1024) + 2097152) * H2 + 8192) / 16384)
    v1 = v1 - ((((v1/32768) * (v1/32768)) / 128 ) * H1) / 16
    if v1 < 0 then
	v1 = 0
	end
    if v1 > 419430400 then
	v1 = 419430400
	end
    h = v1 / 4096
    --print("h=",h)
    return t, p, h
    end
-- expose
M = { read = read }
end
return M
