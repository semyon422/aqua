local socket_url = require("socket.url")
local path_util = require("path_util")
local HttpClient = require("web.http.HttpClient")
local MimeType = require("web.http.MimeType")
local Multipart = require("web.content.Multipart")
local LsTcpSocket = require("web.luasocket.LsTcpSocket")
local NginxTcpSocket = require("web.nginx.NginxTcpSocket")

local util = {}

function util.tcp()
	if ngx then
		return NginxTcpSocket()
	end
	return LsTcpSocket(4)
end

---@return web.HttpClient
function util.client()
	return HttpClient(util.tcp())
end

---@param url string
---@param body table?
---@return string? body
---@return integer|string? status
---@return web.Headers? headers
function util.request(url, body)
	local client = util.client()
	local req, res = client:connect(url)

	local body_str = ""
	if body then
		req.method = "POST"
		req.headers:set("Content-Type", "application/x-www-form-urlencoded")
		body_str = util.encode_query_string(body)
		req:set_length(#body_str)
	end

	local bytes, err = req:send(body_str)
	if not bytes then
		client:close()
		return nil, err
	end

	local _body, err = res:receive("*a")
	if not _body then
		client:close()
		return nil, err
	end

	client:close()

	return _body, res.status, res.headers
end

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

---@param s string?
---@return table
function util.decode_query_string(s)
	local query = {}
	if not s then
		return query
	end
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
	local content_type = req.headers:get("Content-Type")
	if not content_type then
		return nil, "missing content type"
	end

	local mime_type, err = MimeType(content_type)
	if not mime_type then
		return nil, err
	end

	if not mime_type:match("application/x-www-form-urlencoded") then
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

---@param headers web.Headers
---@param filename string
function util.set_download_file_headers(headers, filename)
	headers:set("Cache-Control", "no-cache")
	headers:set("Content-Disposition", ("attachment; filename=%q"):format(path_util.fix_illegal(filename)))
	headers:set("Content-Transfer-Encoding", "binary")  -- https://www.w3.org/Protocols/rfc1341/5_Content-Transfer-Encoding.html
	headers:set("Content-Type", "application/octet-stream")
end

return util
