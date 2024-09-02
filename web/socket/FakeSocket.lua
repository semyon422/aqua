local ISocket = require("web.socket.ISocket")

---@class web.FakeSocket: web.ISocket
---@operator call: web.FakeSocket
local FakeSocket = ISocket + {}

---@param res string|integer?
---@param state "closed"|"timeout"?
function FakeSocket:new(res, state)
	self.res = res
	self.state = state
end

---@param p integer
---@return string?
---@return "closed"|"timeout"?
---@return string?
function FakeSocket:receive(p)
	local state = self.state
	local res = self.res
	---@cast res string
	if state == nil then
		return res
	elseif state == "timeout" then
		return nil, "timeout", res
	elseif state == "closed" then
		return nil, "closed", res
	end
	error()
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function FakeSocket:send(data, i, j)
	local state = self.state
	local res = self.res
	---@cast res integer
	if state == nil then
		return res
	elseif state == "timeout" then
		return nil, "timeout", res
	elseif state == "closed" then
		return nil, "closed", res
	end
	error()
end

return FakeSocket
