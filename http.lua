local https = require("ssl.https")
local socket_http = require("socket.http")
local socket_url = require("socket.url")

local http = {}

function http.request(url, body)
	local string_url = url
	if type(url) ~= "string" then
		string_url = url.url
	end

	local parsed = socket_url.parse(string_url)

	if parsed.scheme == "https" then
		return https.request(url, body)
	end

	return socket_http.request(url, body)
end

return http
