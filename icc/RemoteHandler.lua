local class = require("class")
local Remote = require("icc.Remote")

---@class icc.RemoteHandler
---@operator call: icc.RemoteHandler
local RemoteHandler = class()

---@param th icc.TaskHandler
---@param t table
---@return fun(peer: icc.IPeer, path: string[], is_method: boolean, ...: any): ...: any
function RemoteHandler:create(th, _t)
	return function(peer, path, is_method, ...)
		local remote = Remote(th, peer)

		local s
		local t = _t
		for _, k in ipairs(path) do
			s = t
			t = t[k]
		end

		if is_method then
			return t(s, remote, ...)
		end
		return t(remote, ...)
	end
end

return RemoteHandler
