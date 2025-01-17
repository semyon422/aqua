local class = require("class")
local table_util = require("table_util")

---@alias icc.Key string|number

---@class icc.Remote
---@operator call: icc.Remote
---@operator unm: icc.Remote
---@field [string] icc.Remote
local Remote = class()

---@param th icc.TaskHandler
---@param peer icc.IPeer
---@param path icc.Key[]?
---@param no_return boolean?
function Remote:new(th, peer, path, no_return)
	self.__th = th
	self.__peer = peer
	self.__path = path or {}
	self.__no_return = no_return or false
end

---@param r icc.Remote
---@return icc.TaskHandler
---@return icc.IPeer
---@return icc.Key[]
---@return boolean
local function unpack_remote(r)
	local th = r.__th ---@cast th icc.TaskHandler
	local peer = r.__peer ---@cast peer icc.IPeer
	local path = r.__path ---@cast path icc.Key[]
	local no_return = r.__no_return ---@cast no_return boolean
	return th, peer, path, no_return
end

---@return icc.Remote
function Remote:__unm()
	local th, peer, path, no_return = unpack_remote(self)
	return Remote(th, peer, path, not no_return)
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
	local th, peer, path, no_return = unpack_remote(self)
	return Remote(th, peer, copy_append(path, k), no_return)
end

---@param self icc.Remote
---@param ... any
---@return any ...
local function call(self, ...)
	local th, peer, path, no_return = unpack_remote(self)
	if no_return then
		return th:callnr(peer, path, ...)
	end
	return th:call(peer, path, ...)
end

---@param ... any
---@return any ...
function Remote:__call(...)
	local is_method = getmetatable(...) == Remote
	return call(self, is_method, select(is_method and 2 or 1, ...))
end

return Remote
