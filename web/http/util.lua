local socket_url = require("socket.url")
local MimeType = require("web.http.MimeType")
local Multipart = require("web.content.Multipart")

local util = {}

---@param t table
---@return string
function util.encode_query_string(t)
	local i = 0
	local buf = {}
	for k, v in pairs(t) do
		buf[i + 1] = socket_url.escape(k)
		if v == true then
			buf[i + 2] = "&"
			i = i + 2
		else
			buf[i + 2] = "="
			buf[i + 3] = socket_url.escape(v)
			buf[i + 4] = "&"
			i = i + 4
		end
	end
	buf[i] = nil
	return table.concat(buf)
end

---@param s string
---@return table
function util.decode_query_string(s)
	local query = {}
	s = s .. "&"
	for kv in s:gmatch("([^&]+)&") do
		local k, v = kv:match("^(.-)=(.*)$")
		if k then
			query[socket_url.unescape(k)] = socket_url.unescape(v)
		else
			query[socket_url.unescape(kv)] = true
		end
	end
	return query
end

---@param req web.IRequest
---@return table?
---@return string?
function util.get_form(req)
	local content_type = MimeType(req.headers:get("Content-Type"))
	if not content_type then
		return nil, "missing content type"
	end

	if not content_type:match("application/x-www-form-urlencoded") then
		return nil, "unsupported content type"
	end

	local body, err = req:receive("*a")
	if not body then
		return nil, err
	end

	return util.decode_query_string(body)
end

---@param req web.IRequest
---@return web.Multipart?
---@return string?
function util.get_multipart(req)
	local content_type = MimeType(req.headers:get("Content-Type"))
	if not content_type then
		return nil, "missing content type"
	end

	if not content_type:match("multipart/form-data") then
		return nil, "unsupported content type"
	end

	local boundary = content_type.params.boundary
	if not boundary then
		return nil, "missing boundary"
	end

	return Multipart(req, boundary)
end

return util
