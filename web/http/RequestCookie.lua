local class = require("class")
local table_util = require("table_util")
local CookieSyntax = require("web.http.CookieSyntax")

-- Cookie header

---@class web.RequestCookie
---@operator call: web.RequestCookie
---@field cookie {[string]: string}
---@field keys string[]
---@field cookie_pairs {[1]: string, [2]: string}[]
local RequestCookie = class()

---@param s string?
function RequestCookie:new(s)
	self.cookie = {}
	self.keys = {}
	self.cookie_pairs = {}
	if not s then
		return
	end

	for pair in s:gmatch("[^;]+") do
		local name, value = pair:match("^(.-)=(.*)$")
		if name then
			name, value = CookieSyntax.trim(name), CookieSyntax.trim(value)
			if CookieSyntax.validName(name) and CookieSyntax.validValue(value) then
				if self.cookie[name] == nil then table.insert(self.keys, name) end
				self.cookie[name] = value
				table.insert(self.cookie_pairs, {name, value})
			end
		end
	end
end

---@param name string
---@param value string|number
function RequestCookie:set(name, value)
	value = tostring(value)
	assert(CookieSyntax.validName(name), "invalid cookie name")
	assert(CookieSyntax.validValue(value), "invalid cookie value")
	local cookie, keys = self.cookie, self.keys
	if not cookie[name] then
		table.insert(keys, name)
	end
	cookie[name] = value
	---@type {[1]: string, [2]: string}[]
	local cookie_pairs = {}
	local replaced = false
	for _, pair in ipairs(self.cookie_pairs) do
		if pair[1] ~= name then
			table.insert(cookie_pairs, pair)
		elseif not replaced then
			table.insert(cookie_pairs, {name, value})
			replaced = true
		end
	end
	if not replaced then table.insert(cookie_pairs, {name, value}) end
	self.cookie_pairs = cookie_pairs
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
	for i = #self.cookie_pairs, 1, -1 do
		if self.cookie_pairs[i][1] == name then table.remove(self.cookie_pairs, i) end
	end
end

---@param name string
---@return string[]
function RequestCookie:getAll(name)
	---@type string[]
	local values = {}
	for _, pair in ipairs(self.cookie_pairs) do
		if pair[1] == name then table.insert(values, pair[2]) end
	end
	return values
end

---@param name string
---@return string?
function RequestCookie:get(name)
	return self.cookie[name]
end

---@return string
function RequestCookie:__tostring()
	---@type string[]
	local out = {}
	for _, pair in ipairs(self.cookie_pairs) do
		local name, value = pair[1], pair[2]
		assert(CookieSyntax.validName(name), "invalid cookie name")
		assert(CookieSyntax.validValue(value), "invalid cookie value")
		local kv = ("%s=%s"):format(name, value)
		table.insert(out, kv)
	end
	return table.concat(out, "; ")
end

return RequestCookie
