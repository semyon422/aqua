local IExtendedSocket = require("web.socket.IExtendedSocket")

---@class web.NginxReqSocket: web.IExtendedSocket
---@operator call: web.NginxReqSocket
local NginxReqSocket = IExtendedSocket + {}

function NginxReqSocket:new()
	self.soc = assert(ngx.req.socket(true))
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function NginxReqSocket:receive(pattern, prefix)
	return self.soc:receive(pattern)
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function NginxReqSocket:receiveany(max)
	return self.soc:receiveany(max)
end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function NginxReqSocket:receiveuntil(pattern, options)
	return self.soc:receiveuntil(pattern, options)
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function NginxReqSocket:send(data, i, j)
	i, j = self:normalize_bounds(data, i, j)
	return self.soc:send(data:sub(i, j))
end

---@return 1
function NginxReqSocket:close()
	return self.soc:close()  ---@diagnostic disable-line
end

return NginxReqSocket
