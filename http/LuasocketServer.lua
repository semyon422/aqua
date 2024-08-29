local class = require("class")

local TcpServer = require("http.TcpServer")
local Request = require("http.Request")

---@class http.LuasocketServer
---@operator call: http.LuasocketServer
local LuasocketServer = class()

---@param ip string
---@param port integer
function LuasocketServer:new(ip, port)
	self.tcp_server = TcpServer(ip, port, function(client)
		local req = Request(client)

		local ok, err = req:read_header()
		if not ok then
			return nil, err
		end

		req:send(200, {}, "Hello world")
	end)
end

function LuasocketServer:load()
	self.tcp_server:load()
end

function LuasocketServer:update()
	self.tcp_server:update(0)
end

return LuasocketServer
