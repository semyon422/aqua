local shttp = require("socket.http")
local ltn12 = require("ltn12")

local encodeChar = function(s)
	return ("%%%02X"):format(s:byte())
end

local decodeChar = function(s)
	return string.char(tonumber(s, 16))
end

local encodeUrl = function(s)
	if not s then return end
	return tostring(s):gsub("\n", "\r\n"):gsub("([^%w ])", encodeChar):gsub(" ", "+")
end

local decodeUrl = function(s)
	if not s then return end
	return s:gsub("+", " "):gsub("%%(%x%x)", decodeChar)
end

local encodeParams = function(params)
	local out = {}

	for k, v in pairs(params) do
		out[#out + 1] = encodeUrl(k) .. "=" .. encodeUrl(v)
	end

	return table.concat(out, "&")
end

local http = {}

http.get = function(url, params)
	local body, status

	if params then
		url = (url .. "?" .. encodeParams(params))
	end

	local body, status = shttp.request(url)

	if not body then
		return false, status
	end

	return true, body
end

http.post = function(url, params)
	local body, status = shttp.request(url, encodeParams(params))

	if not body then
		return false, status
	end

	return true, body
end

return http
