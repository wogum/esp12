-- EEPROM I2C Module
-- LICENCE: http://opensource.org/licenses/MIT
-- 2015-07-02 WG

local M
do
-- i2c pins
local sda = 2
local scl = 1
-- i2c addr of EEPROM
local adr = 0x57
-- globals
-- actual address of next write
if _ee == nil then _ee = 0 end
if _eesize == nil then _eesize = 4096 end
-- get c bytes from address a
local function read(a, c)
    local s = nil
    i2c.setup(0, sda, scl, i2c.SLOW)
    i2c.start(0)
    if i2c.address(0, adr, i2c.TRANSMITTER) then
	i2c.write(0, a / 256 % 256)
	i2c.write(0, a % 256)
	i2c.stop(0)
	i2c.start(0)
	i2c.address(0, adr, i2c.RECEIVER)
	s=i2c.read(0, c)
    end
    i2c.stop(0)
    return s
end
-- put s at address a
local function write(a,s)
    local r
    i2c.setup(0, sda, scl, i2c.SLOW)
    repeat	-- wait until internal write ends
	i2c.start(0)
	r = i2c.address(0, adr, i2c.TRANSMITTER)
	i2c.stop(0)
	tmr.wdclr()
    until r
    i2c.start(0)
    i2c.address(0, adr, i2c.TRANSMITTER)
    i2c.write(0, a / 256 % 256)
    i2c.write(0, a %256)
    i2c.write(0, s)
    i2c.stop(0)
end
-- fill up all the EEPROM with 0xFF
local function format()
    local page = 32
    if _eesize >= 16384 then page = 64 end
    if _eesize >= 65536 then page = 128 end
    local s = string.rep(string.char(0xFF), page)
    for a=0, _eesize-page, page do
	write(a, s)
	tmr.wdclr()
    end
    _ee = 0
    s=nil
end
-- get address of first 0xFF data in EE at addr/8
local function find()
    local r = nil
    for a=0, _eesize-8, 8 do
	if read(a,1):byte(1) == 0xFF then
	    r = a
	    break
	end
	tmr.wdclr()
    end
    return r
end
-- pack date to 4-byte like FAT16 
local function packDate(h, n, s, y, m, d, w)
    return string.char( y%100*2+m/8, m%8*32+d, h*8+n/8, n%8*32+s/2 )
end
-- unpack date 
-- ret: h,n,s,y,m,d
local function unpackDate(s)
    return s:byte(3)/8, s:byte(3)%8*8+s:byte(4)/32, s:byte(4)%32*2, 
	2000+s:byte(1)/2, s:byte(1)%2*8+s:byte(2)/32, s:byte(2)%32
end
-- pack 3 values in miliC to 4 bytes (12-bit decyC, 12-bit decyC, 8-bit C)
local function packTemp(t1, t2, t3)
    if t2 == nil then t2 = 0 end
    if t3 == nil then t3 = 0 end
    return string.char( t1/100/16%256, t1/100%16*16+t2/100/256%16, t2/100%256, t3/1000%256 )
end
-- unpack 4-bytes to t1,t2,t3
local function unpackTemp(s)
    local t1 = s:byte(1)*16+s:byte(2)/16
    if t1>2047 then t1 = t1 - 4096 end
    t1 = 100 * t1
    local t2 = s:byte(2)%16*256+s:byte(3)
    if t2>2047 then t2 = t2 - 4096 end
    t2 = 100 * t2
    local t3 = s:byte(4)
    if t3>127 then t3 = t3 - 256 end
    t3 = 1000 * t3
    return t1, t2, t3
end
-- get 8 byte chunk as CSV line from EEPROM
local function chunkRead(a, len)
    local e
    local r = ""
    if len == nil then len = 8 end
    len = a + len
    e = read(a, 8)
    while a < len and e:byte(1) ~= 0xFF do
	local h, n, s, y, m, d = unpackDate(e)
	local t1, t2, t3 = unpackTemp(e:sub(5,8))
	r = r .. string.format("%d-%02d-%02d;%02d:%02d:%02d;%d.%d;%d.%d;%d\n", 
	    y, m, d, h, n, s, t1/1000, t1%1000/100, t2/1000, t2%1000/100, t3/1000)
	a = (a + 8) % _eesize
	e = read(a, 8)
    end
    return r
end
-- write 8 byte chunk to EEPROM
local function chunkWrite(a,t1,t2,t3,h,n,s,y,m,d,w)
    local s = packDate(h,n,s,y,m,d) .. packTemp(t1,t2,t3)
    write(a,s)
end
-- export functions
M = { read = read, write = write, find = find, format = format, chunkRead = chunkRead, chunkWrite = chunkWrite
    , packTemp = packTemp, unpackTemp = unpackTemp }
end
return M
