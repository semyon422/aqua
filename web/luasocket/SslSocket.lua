local ISocket = require("web.socket.ISocket")

---@class web.SslSocket: web.ISocket
---@operator call: web.SslSocket
local SslSocket = ISocket + {}

---@param soc web.ISocket
function SslSocket:new(soc)
	self.soc = soc
end

---@param size integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function SslSocket:receive(size)
	local data, err, partial = self.soc:receive(size)
	if err == "wantread" then  -- SSL error
		err = "timeout"
	end
	return data, err, partial
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function SslSocket:send(data, i, j)
	return self.soc:send(data, i, j)
end

---@return 1
function SslSocket:close()
	return self.soc:close()
end

return SslSocket
