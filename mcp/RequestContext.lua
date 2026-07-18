local class = require("class")

---@alias mcp.CancelHandler fun(reason: string)

---@class mcp.RequestContext
---@operator call: mcp.RequestContext
---@field request_id string|number
---@field canceled boolean
---@field cancel_reason string?
---@field cancel_handlers mcp.CancelHandler[]
local RequestContext = class()

---@param request_id string|number
function RequestContext:new(request_id)
	self.request_id = request_id
	self.canceled = false
	self.cancel_handlers = {}
end

---@param handler mcp.CancelHandler
function RequestContext:onCancel(handler)
	if self.canceled then
		handler(assert(self.cancel_reason))
		return
	end
	table.insert(self.cancel_handlers, handler)
end

---@param reason string?
---@return boolean canceled
---@return string? handler_error
function RequestContext:cancel(reason)
	if self.canceled then
		return false
	end
	self.canceled = true
	self.cancel_reason = reason or "MCP request canceled"
	local first_error
	for _, handler in ipairs(self.cancel_handlers) do
		local ok, err = xpcall(handler, debug.traceback, self.cancel_reason)
		if not ok and not first_error then
			first_error = tostring(err)
		end
	end
	self.cancel_handlers = {}
	return true, first_error
end

---@return true?
---@return string?
function RequestContext:checkCanceled()
	if self.canceled then
		return nil, self.cancel_reason
	end
	return true
end

return RequestContext
