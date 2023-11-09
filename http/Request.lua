local http_codes = require("http.codes")
local async_client = require("http.async_client")
local class = require("class")

---@class http.Request
---@operator call: http.Request
local Request = class()

function Request:new(client)
	self.client = client
end

function Request:ireceive()
	local length = self.length
	local body_size = 0
	return function()
		if body_size == length then
			return
		end

		coroutine.yield()
		local line, err, partial = self.client:receive(length - body_size)  -- closed | timeout
		if err == "closed" then
			return nil, err
		end

		local data = line or partial
		body_size = body_size + #data

		return data
	end
end

function Request:receive()
	if self.length == 0 then
		return ""
	end
	return async_client.receive(self.client, self.length)
end

function Request:send(code, headers, body)
	headers["Content-Length"] = #body

	local res = {
		("HTTP/1.1 %s %s"):format(code, http_codes[code]),
	}

	for k, v in pairs(headers) do
		table.insert(res, ("%s: %s"):format(k, v))
	end
	table.insert(res, "")
	table.insert(res, body)

	return async_client.send(self.client, table.concat(res, "\r\n"))
end

function Request:read_header()
	self.headers = {}
	while true do
		local line, err = async_client.receive(self.client, "*l")  -- closed
		if not line then
			return nil, err
		end

		if not self.method then
			self.method, self.uri, self.protocol = line:match("^(%S+)%s+(%S+)%s+(%S+)")
		else
			local key, value = line:match("^(%S+):%s+(.+)")
			if key then
				self.headers[key] = value
			end
		end
		if line == "" then
			break
		end
	end
	self.length = tonumber(self.headers["Content-Length"]) or 0
	return true
end

return Request
