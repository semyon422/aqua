local IHandler = require("icc.IHandler")
local Remote = require("icc.Remote")

---@alias icc.RemoteFunction fun(remote: icc.Remote, ...: any): ...: any
---@alias icc.RemoteMethod fun(self: table, remote: icc.Remote, ...: any): ...: any

---@class icc.RemoteHandler: icc.IHandler
---@operator call: icc.RemoteHandler
local RemoteHandler = IHandler + {}

---@param t {[any]: [any]}
function RemoteHandler:new(t)
	self.t = t
end

---@param th icc.TaskHandler
---@param peer icc.IPeer
---@param path string[]
---@param is_method boolean
---@param ... any
---@return any ...
function RemoteHandler:handle(th, peer, path, is_method, ...)
	local remote = Remote(th, peer)

	---@type any
	local s
	local t = self.t
	for _, k in ipairs(path) do
		s = t
		t = t[k]
	end

	if is_method then
		---@cast t -any, +icc.RemoteMethod
		return t(s, remote, ...)
	end

	---@cast t -any, +icc.RemoteFunction
	return t(remote, ...)
end

return RemoteHandler
