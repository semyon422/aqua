local class = require("class")
local Remote = require("icc.Remote")

---@alias icc.RemoteFunction fun(remote: icc.Remote, ...: any): ...: any
---@alias icc.RemoteMethod fun(self: table, remote: icc.Remote, ...: any): ...: any

---@class icc.RemoteHandler
---@operator call: icc.RemoteHandler
local RemoteHandler = class()

---@param th icc.TaskHandler
---@param _t {[any]: [any]}
function RemoteHandler:new(th, _t)
	self.th = th
	self._t = _t
end

---@param peer icc.IPeer
---@param path string[]
---@param is_method boolean
---@param ... any
---@return any ...
function RemoteHandler:handle(peer, path, is_method, ...)
	local remote = Remote(self.th, peer)

	---@type any
	local s
	local t = self._t
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
