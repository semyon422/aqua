local class = require("class")
local table_util = require("table_util")

---@alias icc.Key string|number

---@class icc.Remote
---@operator call: icc.Remote
---@field [string] icc.Remote
local Remote = class()

---@param th icc.TaskHandler
---@param peer icc.IPeer
---@param path icc.Key[]?
function Remote:new(th, peer, path)
	self.__th = th
	self.__peer = peer
	self.__path = path or {}
end

---@param r icc.Remote
---@return icc.TaskHandler
---@return icc.IPeer
---@return icc.Key[]
local function unpack_remote(r)
	local th = r.__th ---@cast th icc.TaskHandler
	local peer = r.__peer ---@cast peer icc.IPeer
	local path = r.__path ---@cast path icc.Key[]
	return th, peer, path
end

---@param path icc.Key[]
---@param k icc.Key
---@return icc.Key[]
local function copy_append(path, k)
	local _path = table_util.copy(path)
	---@cast _path icc.Key[]
	table.insert(_path, k)
	return _path
end

---@param k icc.Key
---@return icc.Remote
function Remote:__index(k)
	local th, peer, path = unpack_remote(self)
	return Remote(th, peer, copy_append(path, k))
end

---@param ... any
---@return any ...
function Remote:__call(...)
	local is_method = getmetatable(...) == Remote
	local th, peer, path = unpack_remote(self)
	return th:call(peer, path, is_method, select(is_method and 2 or 1, ...))
end

return Remote
