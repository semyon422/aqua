local IExtendedSocket = require("web.socket.IExtendedSocket")

---@class web.PrefixSocket: web.IExtendedSocket
---@operator call: web.PrefixSocket
local PrefixSocket = IExtendedSocket + {}

---@param soc web.IExtendedSocket
function PrefixSocket:new(soc)
	self.soc = soc
end

---@param prefix string
---@param data string?
---@param err "closed"|"timeout"?
---@param partial string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
local function concat_prefix(prefix, data, err, partial)
	if data then
		return prefix .. data, err, partial
	end
	return data, err, prefix .. partial
end

---@param pattern "*a"|"*l"|integer?
---@param prefix string?
---@return string?
---@return "closed"|"timeout"?
---@return string?
function PrefixSocket:receive(pattern, prefix)
	assert(pattern == "*a" or pattern == "*l" or type(pattern) == "number", "invalid pattern")

	if not prefix or prefix == "" then
		return self.soc:receive(pattern)
	end

	if type(pattern) == "number" then
		pattern = pattern - #prefix
		if prefix and pattern <= 0 then
			return prefix
		end
	end

	return concat_prefix(prefix, self.soc:receive(pattern))
end

---@param max integer
---@return string?
---@return "closed"|"timeout"?
function PrefixSocket:receiveany(max)
	return self.soc:receiveany(max)
end

---@param pattern string
---@param options {inclusive: boolean?}?
---@return fun(size: integer?): string?, "closed"|"timeout"?, string?
function PrefixSocket:receiveuntil(pattern, options)
	return self.soc:receiveuntil(pattern, options)
end

---@param data string
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function PrefixSocket:send(data)
	return self.soc:send(data)
end

---@return 1
function PrefixSocket:close()
	return self.soc:close()
end

return PrefixSocket
