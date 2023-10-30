local socket_url = require("socket.url")

local cookie_util = {}

function cookie_util.decode(s)
	if not s then
		return {}
	end
	local cookies = {}
	for k, v in s:gmatch("([^=%s]*)=([^;]*)") do
		cookies[socket_url.unescape(k)] = socket_url.unescape(v)
	end
	return cookies
end

function cookie_util.encode(cookies)
	if not cookies then
		return
	end
	local out = {}
	for k, v in pairs(cookies) do
		local kv = ("%s=%s"):format(socket_url.escape(k), socket_url.escape(v))
		table.insert(out, kv)
	end
	table.insert(out, "Path=/")
	table.insert(out, "HttpOnly")
	return table.concat(out, "; ")
end

return cookie_util
