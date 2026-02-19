local table_util = require("table_util")
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

---@param ctx icc.IPeerContext
---@param obj table
---@param ... any
---@return any ...
function RemoteHandler:transform(ctx, obj, ...)
	---@type table? real *Remote or icc.Remote or nil
	local real_obj = obj.remote -- `obj` is validation

	local wrapped_obj = setmetatable({}, {__index = real_obj or obj, __is_wrapped_obj = true})

	-- when real_obj is icc.Remote, __is_wrapped_obj is required
	-- for __call to work on wrapped_obj

	table_util.copy(ctx, wrapped_obj)

	if real_obj then
		-- in this case `ctx` copied into wrapped `remote`
		local val = setmetatable({}, getmetatable(obj))
		wrapped_obj, val.remote = val, wrapped_obj
	end

	return wrapped_obj, ...
end

---@param ctx icc.IPeerContext
---@param path string[]
---@param is_method boolean
---@param ... any
---@return any ...
function RemoteHandler:handle(ctx, path, is_method, ...)
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
			---@cast _wl -true
			whitelist = _wl ---@diagnostic disable-line: no-unknown
		end

		_self, value, prev_key = value, value[k], k
	end

	local _type = type(value)
	if _type ~= "function" then
		error(("attempt to call field '%s' (a %s value)"):format(prev_key, _type))
	end

	---@cast value -table, +function
	return value(select(is_method and 1 or 2, self:transform(ctx, _self, ...)))
end

return RemoteHandler
