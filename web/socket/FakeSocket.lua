local ISocket = require("web.socket.ISocket")

---@class web.FakeSocket: web.ISocket
---@operator call: web.FakeSocket
local FakeSocket = ISocket + {}

---@param results {[1]: string|integer, [2]: "closed"|"timeout"}[]
function FakeSocket:new(results)
	self.results = results
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function FakeSocket:receive(pattern, prefix)
	---@type string, "closed"|"timeout"
	local res, state = unpack(table.remove(self.results, 1))
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
	---@type integer, "closed"|"timeout"
	local res, state = unpack(table.remove(self.results, 1))
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
