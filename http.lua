local https = require("ssl.https")
local socket_http = require("socket.http")

-- TODO: delete

local http = {}

---@param url string|table
---@param body string?
---@return string|number?
---@return string|number?
---@return table?
---@return string?
function http.request(url, body)
	local q, w, e, r = https.request(url, body)

	if q then
		return q, w, e, r
	end

	return socket_http.request(url, body)
end

return http
