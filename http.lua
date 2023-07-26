local https = require("ssl.https")
local socket_http = require("socket.http")

local http = {}

function http.request(url, body)
	local q, w, e, r = https.request(url, body)

	if q then
		return q, w, e, r
	end

	return socket_http.request(url, body)
end

return http
