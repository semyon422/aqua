local DecoratorSocket = require("web.socket.DecoratorSocket")

---@class web.PrefixSocket: web.DecoratorSocket
---@operator call: web.PrefixSocket
local PrefixSocket = DecoratorSocket + {}

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

return PrefixSocket
