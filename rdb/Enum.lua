local table_util = require("table_util")
local class = require("class")

---@class rdb.Enum
---@operator call: rdb.Enum
local Enum = class()

---@param t {[string]: integer}
function Enum:new(t)
	self.t = t
	self._t = table_util.invert(t)
end

---@return string[]
function Enum:list()
	local list = table_util.copy(self._t)
	---@cast list string[]
	table.sort(list)
	return list
end

---@param k string
---@return integer
function Enum:encode(k)
	local v = self.t[k]
	if v then
		return v
	end
	error("can not encode '" .. tostring(k) .. "'")
end

---@param v integer
---@return string
function Enum:decode(v)
	local k = self._t[v]
	if k then
		return k
	end
	error("can not decode '" .. tostring(v) .. "'")
end

return Enum
