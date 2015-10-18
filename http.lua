-- send data to web server
--
-- 2015.07.10 WG
--
-- Example:
--  dofile("http.lua").post(_ee-786)
--
local M
do
-- Send data to HTTP server using POST method
local function post(a)
    if wifi.sta.status() ~= 5 or _cfg["host"] == nil or _cfg["uri"] == nil then return end
    local post = "node="..node.chipid().."&ver=".._ver.."&mac="..wifi.sta.getmac().."&ip="..wifi.sta.getip().."&"
    for i=1,#_addr do
	post = post .. "a[]=" .. _addr[i] .. "&t[]=" .. _temp[i] .. "&"
    end
    if a == nil then a = _ee - 768 end
    if a < 0 then a = 0 end
    if _debug then print("#post",post,a) end
    post = post .. "ee=" .. crypto.toBase64(dofile("ee.lc").read(a, 768))
    a = nil
    local request = "POST " .. _cfg["uri"] .. " HTTP/1.1\r\nHost: " .. _cfg["host"]
	.. "\r\nConnection: close\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: " 
	.. string.len(post) .. "\r\n\r\n" .. post
    post = nil
    local socket = net.createConnection(net.TCP, 0)
    socket:on("connection", function(sck)
	sck:send(request)
    if _debug then print("#post sent",#request) end
	request = nil
    end)
    socket:on("receive", function(sck, response)
	sck:close()
	-- response commands
	if string.find(response, "\?") then
	    dofile("config.lc").decode(response)
	end
    end)
    socket:connect(80, _cfg["host"])
end
-- export functions
M = { post = post }
end
return M