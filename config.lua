-- Configuration load and save for NodeMCU
-- LICENCE: http://opensource.org/MIT
--
-- 2015.07.10 WG
local M
do
-- load config from config file
local function load()
    file.open("config", "r")
    _cfg = cjson.decode(file.read(1400))
    file.close()
end
-- save config to config file
local function save()
    file.open("config", "w")
    file.writeline(cjson.encode(_cfg))
    file.close()
end
local function url_decode(str)
    str = string.gsub(str, "+", " ")
    str = string.gsub(str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
    str = string.gsub(str, "\r\n", "\n")
    return str
end
-- decode and set config from request URL
local function decode(request)
    local buf
    _, _, buf = string.find(request, "dt=(\-?%d+)") 
    if buf ~= nil then
	_cfg["dt"][1] = tonumber(buf)
    end
    _, _, buf = string.find(request, "tz=(\-?%d+)") 
    if buf ~= nil then
	_cfg["tz"] = tonumber(buf)
    end
    _, _, buf = string.find(request, "slp=(\%d+)") 
    if buf ~= nil then
	_cfg["slp"] = tonumber(buf)
    end
    _, _, buf = string.find(request, "rec=(%d+)") 
    if buf ~= nil and tonumber(buf) >= 1 then
	_cfg["rec"] = tonumber(buf)
    end
    _, _, buf = string.find(request, "ssid=([^%s&]+)") 
    if buf ~= nil then
	_cfg["ssid"] = url_decode(buf)
    end
    _, _, buf = string.find(request, "pwd=([^%s&]+)") 
    if buf ~= nil then
	_cfg["pwd"] = url_decode(buf)
    end
    _, _, buf = string.find(request, "host=([^%s&]+)") 
    if buf ~= nil then
	_cfg["host"] = url_decode(buf)
    end
    _, _, buf = string.find(request, "uri=([^%s&]+)") 
    if buf ~= nil then
	_cfg["uri"] = url_decode(buf)
    end
    _, _, buf = string.find(request, "ntp=([^%s&]+)") 
    if buf ~= nil then
	_cfg["ntpserver"] = url_decode(buf)
    end
-- save configuration afrer changes
    save()
-- check remove data
    if string.find(request, "rm=1", 1 , true) then 
	dofile("ee.lc").format()
    end
-- check restart device
    if string.find(request, "rst=1", 1 , true) then 
	node.restart()
    end
    buf = nil
    _ = nil
end
-- export functions
M = { load = load, save = save, decode = decode }
end
return M