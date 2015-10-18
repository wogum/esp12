--- WWW HTTP server for BME280 on NodeMCU ESP-12 (ESP8266)
--- Licence MIT
--- 2015-10-16 WG
-- globals
_file = ""
_head = ""
-- locals
if srv then
    srv:close()
    srv = nil
end
-- large file send thread routine based on https://github.com/marcoskirsch/nodemcu-httpserver
sendFile = nil
function sendFile(conn)
    local cont = true
    local pos = 0
    local chunk = ""
    conn:send(_head)
    _head = nil
    while cont and #_file > 0 do
	collectgarbage()
	file.open(_file, "r")
	file.seek("set", pos)
	chunk = file.read(1400)
	file.close()
	if chunk == nil then
	    cont = false
	else
	    coroutine.yield()
	    conn:send(chunk)
	    pos = pos + #chunk
	    chunk = nil
	end
    end
end
-- http server
srv=net.createServer(net.TCP, 30)
srv:listen(80, function(conn)
    local connTh
    conn:on("receive", function(client, request)
	collectgarbage()
	local buf = ""
	-- parse parameters
	if string.find(request, "\?") then
	    dofile("config.lc").decode(request)
	end
	if string.find(request, "/cfg", 1, true) then
	    file.open("config", "r")
	    buf = file.read(1400)
	    file.close()
	    buf = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
	    .. buf
	    conn:send(buf)
	elseif string.find(request, "/json", 1, true) then
	    buf = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\n\r\n"
	    .. "{" .. "\"t\":" .. cjson.encode(_temp) .. ",\"a\":" .. cjson.encode(_addr)
	    .. ",\"date\":\"" .. dofile("ds32.lc").date()  .. "\",\"time\":\"" .. dofile("ds32.lc").time()
	    .. "\",\"node\":\"" .. node.chipid() .. "\",\"mac\":\"" .. wifi.sta.getmac()
	    .. "\",\"mem\":" .. node.heap() .. ", \"disk\":" .. (_eesize-_ee) .. ",\"uptime\":" .. tmr.time()
	    .. ",\"ver\":\"" .. _ver .. "\"}"
	    conn:send(buf)
	elseif string.find(request, "favicon", 1, true) then
	    buf = "HTTP/1.1 404 Not Found\r\n\r\n"
	    conn:send(buf)
	elseif string.find(request, "/ee", 1, true) then
	    local a
	    a, a, buf = string.find(request, "ee=(%d+)") 
	    if buf ~= nil and tonumber(buf) >= 0 then
		a = tonumber(buf)
	    else
		a = _ee - 1024
	    end
	    if a < 0 then a = 0 end
	    buf = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n"  .. crypto.toBase64(dofile("ee.lc").read(a, 1024))
	    a = nil
	    conn:send(buf)
	elseif string.find(request, "/config", 1, true) then
	    _file = "config.html"
	    _head = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n"
	    connTh = coroutine.create(sendFile)
	else
--	    if string.find(request, "ncoding:.*gzip") then
--		_file = "index.html.gz"
--		_head = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Encoding: gzip\r\n\r\n"
--	    else
		_file = "index.html"
		_head = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n"
--	    end
	    connTh = coroutine.create(sendFile)
	end
	-- large file send
	if connTh then coroutine.resume(connTh, client) end
	buf = nil
    end)
    conn:on("sent", function(conn) 
	if connTh then
	    local connThStatus = coroutine.status(connTh)
	    if connThStatus == "suspended" then
		coroutine.resume(connTh)
	    elseif connThStatus == "dead" then
		conn:close()
		connTh = nil
	    end
	else
	    conn:close() 
	end
    end)
end)