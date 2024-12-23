local class = require("class")
local table_util = require("table_util")
local socket_url = require("socket.url")

-- Set-Cookie headers

---@class web.ResponseCookie
---@operator call: web.ResponseCookie
---@field params {[string]: string}
---@field keys string[]
---@field name string
---@field value string
local ResponseCookie = class()

local kv_pattern = "^%s*(.*)%s*=%s*(.*)%s*$"

---@param s string?
function ResponseCookie:new(s)
	self.params = {}
	self.keys = {}

	if not s then
		return
	end

	---@type string, string
	local name_value, params = s:match("^(.-)(;.+)$")
	if not name_value then
		self.name, self.value = s:match(kv_pattern)
		return
	end

	self.name, self.value = name_value:match(kv_pattern)

	for param in params:gmatch(";%s*([^;]*)%s*") do
		local name, value = param:match(kv_pattern)
		if name then
			self:set(name, value)
		else
			self:set(param)
		end
	end
end

---@param name string
---@param value any?
function ResponseCookie:set(name, value)
	local params, keys = self.params, self.keys
	if not params[name] then
		table.insert(keys, name)
	end
	if not value then
		return
	end
	params[name] = tostring(value)
end

---@param name string
function ResponseCookie:unset(name)
	local params, keys = self.params, self.keys
	local index = table_util.indexof(keys, name)
	if not index then
		return
	end
	table.remove(keys, index)
	params[name] = nil
end

---@param name string
---@return string?
function ResponseCookie:get(name)
	return self.params[name]
end

---@param name string
---@return boolean
function ResponseCookie:exists(name)
	return not not table_util.indexof(self.keys, name)
end

---@return string
function ResponseCookie:__tostring()
	local params, keys = self.params, self.keys
	local out = {("%s=%s"):format(self.name, self.value)}
	for _, key in ipairs(keys) do
		local name = socket_url.escape(key)
		local value = params[key]
		if type(value) == "string" then
			table.insert(out, ("%s=%s"):format(name, socket_url.escape(value)))
		else
			table.insert(out, ("%s"):format(name))
		end
	end
	return table.concat(out, "; ")
end

return ResponseCookie
