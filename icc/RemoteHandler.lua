local IHandler = require("icc.IHandler")
local Remote = require("icc.Remote")

---@class icc.RemoteHandler: icc.IHandler
---@operator call: icc.RemoteHandler
local RemoteHandler = IHandler + {}

---@param t {[any]: [any]}
function RemoteHandler:new(t)
	self.t = t
end

---@param th icc.TaskHandler
---@param peer icc.IPeer
---@param obj table
---@param ... any
---@return any ...
function RemoteHandler:transform(th, peer, obj, ...)
	return obj, Remote(th, peer), ...
end

---@param th icc.TaskHandler
---@param peer icc.IPeer
---@param path string[]
---@param is_method boolean
---@param ... any
---@return any ...
function RemoteHandler:handle(th, peer, path, is_method, ...)
	---@type any
	local s, t = nil, self.t
	for _, k in ipairs(path) do
		s, t = t, t[k]
	end

	---@cast t -table, +function
	return t(select(is_method and 1 or 2, self:transform(th, peer, s, ...)))
end

return RemoteHandler
