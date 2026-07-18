---@param soc web.IExtendedSocket
---@param max_size integer?
---@return string?
---@return "closed"|"timeout"|"line too long"?
---@return string?
local function receive_line(soc, max_size)
	if not max_size then
		return soc:receive("*l")
	end
	assert(max_size >= 0, "max_size must be non-negative")

	local reader = soc:receiveuntil("\r\n")
	local line, err, partial = reader(max_size + 1)
	if line and #line > max_size then
		return nil, "line too long", line
	end
	return line, err, partial
end

return receive_line
