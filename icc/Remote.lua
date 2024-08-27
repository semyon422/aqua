local class = require("class")
local table_util = require("table_util")

---@class icc.Remote
---@operator call: icc.Remote
---@field [string] icc.Remote
local Remote = class()

---@param th icc.TaskHandler
---@param peer icc.IPeer
---@param path string[]?
function Remote:new(th, peer, path)
	self.__th = th
	self.__peer = peer
	self.__path = path or {}
end

---@param k string|number
---@return icc.Remote
function Remote:__index(k)
	local path = table_util.copy(self.__path)
	table.insert(path, k)
	return Remote(self.__th, self.__peer, path)
end

---@param ... any
---@return any ...
function Remote:__call(...)
	local is_method = getmetatable(...) == Remote
	return self.__th:call(
		self.__peer,
		self.__path,
		is_method,
		select(is_method and 2 or 1, ...)
	)
end

return Remote
