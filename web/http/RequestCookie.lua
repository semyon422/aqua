local class = require("class")
local table_util = require("table_util")
local socket_url = require("socket.url")

-- Cookie header

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

	---@diagnostic disable-next-line: no-unknown
	for k, v in s:gmatch("([^=%s]*)=([^;]*)") do
		self:set(socket_url.unescape(k), socket_url.unescape(v))
	end
end

---@param name string
---@param value any?
function RequestCookie:set(name, value)
	local cookie, keys = self.cookie, self.keys
	if not cookie[name] then
		table.insert(keys, name)
	end
	cookie[name] = tostring(value)
end

---@param name string
function RequestCookie:unset(name)
	local cookie, keys = self.cookie, self.keys
	local index = table_util.indexof(keys, name)
	if not index then
		return
	end
	table.remove(keys, index)
	cookie[name] = nil
end

---@param name string
---@return string?
function RequestCookie:get(name)
	return self.cookie[name]
end

---@return string
function RequestCookie:__tostring()
	local cookie, keys = self.cookie, self.keys
	local out = {}
	for _, key in ipairs(keys) do
		local name, value = socket_url.escape(key), socket_url.escape(cookie[key])
		local kv = ("%s=%s"):format(name, value)
		table.insert(out, kv)
	end
	return table.concat(out, "; ")
end

return RequestCookie
