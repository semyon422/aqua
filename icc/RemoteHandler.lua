local IHandler = require("icc.IHandler")
local Remote = require("icc.Remote")

---@class icc.RemoteHandlerWhitelist
---@field [string] true|icc.RemoteHandlerWhitelist?

---@class icc.RemoteHandler: icc.IHandler
---@operator call: icc.RemoteHandler
local RemoteHandler = IHandler + {}

---@param t {[any]: [any]}
---@param whitelist icc.RemoteHandlerWhitelist?
function RemoteHandler:new(t, whitelist)
	self.t = t
	self.whitelist = whitelist
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
	local whitelist = self.whitelist

	---@type any
	local _self, value, prev_key = nil, self.t, nil
	for _, k in ipairs(path) do
		local _type = type(value)
		if _type ~= "table" then
			error(("attempt to index field '%s' (a %s value)"):format(prev_key, _type))
		end

		if whitelist then
			local _wl = whitelist[k]
			if not _wl then
				error(("attempt to get field '%s' (not whitelisted)"):format(k))
			end
			whitelist = _wl
		end

		_self, value, prev_key = value, value[k], k
	end

	local _type = type(value)
	if _type ~= "function" then
		error(("attempt to call field '%s' (a %s value)"):format(prev_key, _type))
	end

	---@cast value -table, +function
	return value(select(is_method and 1 or 2, self:transform(th, peer, _self, ...)))
end

return RemoteHandler
