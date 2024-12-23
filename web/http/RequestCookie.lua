local class = require("class")
local table_util = require("table_util")
local socket_url = require("socket.url")

---@class web.RequestCookie
---@operator call: web.RequestCookie
---@field cookie {[string]: string}
---@field keys string[]
local RequestCookie = class()

---@param s string?
function RequestCookie:new(s)
	self.cookie = {}
	self.keys = {}
	if not s then
		return
	end

	local cookie, keys = self.cookie, self.keys

	for k, v in s:gmatch("([^=%s]*)=([^;]*)") do
		self:set(socket_url.unescape(k), socket_url.unescape(v))
	end
end

---@param k string
---@param v any?
function RequestCookie:set(k, v)
	local cookie, keys = self.cookie, self.keys
	if not cookie[k] then
		table.insert(keys, k)
	end
	cookie[k] = tostring(v)
end

---@param k string
function RequestCookie:unset(k)
	local cookie, keys = self.cookie, self.keys
	local index = table_util.indexof(keys, k)
	if not index then
		return
	end
	table.remove(keys, index)
	cookie[k] = nil
end

---@param k string
function RequestCookie:get(k)
	return self.cookie[k]
end

---@return string
function RequestCookie:__tostring()
	local cookie, keys = self.cookie, self.keys
	local out = {}
	for _, k in ipairs(keys) do
		local k, v = socket_url.escape(k), socket_url.escape(cookie[k])
		local kv = ("%s=%s"):format(k, v)
		table.insert(out, kv)
	end
	return table.concat(out, "; ")
end

return RequestCookie
