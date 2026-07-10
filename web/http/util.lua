local socket_url = require("socket.url")
local path_util = require("path_util")
local table_util = require("table_util")
local dpairs = require("dpairs")
local json = require("web.json")
local HttpClient = require("web.http.HttpClient")
local MimeType = require("web.http.MimeType")
local Multipart = require("web.content.Multipart")
local MultipartString = require("web.content.MultipartString")
local CosocketTcpSocket = require("web.luasocket.CosocketTcpSocket")
local LsTcpSocket = require("web.luasocket.LsTcpSocket")
local NginxTcpSocket = require("web.nginx.NginxTcpSocket")

local util = {}

---@class web.HttpClientOptions
---@field scheduler web.CosocketScheduler?
---@field ip_version 4|6?
---@field tcp_socket web.ITcpSocket?
---@field timeout number?
---@field ssl_params web.SslParams?
---@field connect_host string?

---@param options web.HttpClientOptions?
---@return 4|6
local function get_ip_version(options)
	if options and options.ip_version then
		return options.ip_version
	end
	return 4
end

---@param tcp_socket web.ITcpSocket
---@param options web.HttpClientOptions?
---@return web.ITcpSocket
local function configure_tcp(tcp_socket, options)
	if not options then
		return tcp_socket
	end
	if options.timeout then
		tcp_socket:settimeout(options.timeout)
	end
	if options.ssl_params then
		tcp_socket.ssl_params = table_util.deepcopy(options.ssl_params)
	end
	return tcp_socket
end

---@param options web.HttpClientOptions?
---@return web.ITcpSocket
function util.tcp(options)
	---@type web.ITcpSocket
	local tcp_socket
	if options and options.tcp_socket then
		tcp_socket = options.tcp_socket
	elseif options and options.scheduler then
		tcp_socket = CosocketTcpSocket(options.scheduler, get_ip_version(options))
	elseif ngx then
		tcp_socket = NginxTcpSocket()
	else
		tcp_socket = LsTcpSocket(get_ip_version(options))
	end

	---@cast tcp_socket -?

	return configure_tcp(tcp_socket, options)
end

---@param options web.HttpClientOptions?
---@return web.HttpClient
function util.client(options)
	return HttpClient(util.tcp(options))
end

---@param url string
---@param body table?
---@param options web.HttpClientOptions?
---@return {status: integer, headers: web.Headers, body: string}?
---@return string?
function util.request(url, body, options)
	local client = util.client(options)
	local req, res = client:connect(url, options and options.connect_host)

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

	return {
		status = res.status,
		headers = res.headers,
		body = _body,
	}
end

---@param t {[string]: any}
---@return string
function util.encode_query_string(t)
	local i = 0
	---@type string[]
	local buf = {}
	for k, v in dpairs(t) do
		buf[i + 1] = socket_url.escape(k)
		buf[i + 2] = "="
		buf[i + 3] = socket_url.escape(tostring(v))
		buf[i + 4] = "&"
		i = i + 4
	end
	buf[i] = nil
	return table.concat(buf)
end

---@param s string?
---@return {[string]: string}
function util.decode_query_string(s)
	---@type {[string]: string}
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
			query[socket_url.unescape(kv)] = ""
		end
	end
	return query
end


---@param ... table
---@return string
function util.query(...)
	local t = {}
	for i = 1, select("#", ...) do
		local src = select(i, ...)
		if src then
			table_util.copy(src, t)
		end
	end
	return util.encode_query_string(t)
end

---@param req web.IRequest
---@return {[string]: string}?
---@return string?
function util.get_form(req)
	local content_type_str = req.headers:get("Content-Type")
	if not content_type_str then
		return nil, "missing content type"
	end

	local content_type, err = MimeType(content_type_str)
	if not content_type then
		return nil, err
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
---@param opts {read_all: boolean?}?
---@return web.IMultipart?
---@return string?
function util.get_multipart(req, opts)
	opts = opts or {}

	local content_type_str = req.headers:get("Content-Type")
	if not content_type_str then
		return nil, "missing content type"
	end

	local content_type, err = MimeType(content_type_str)
	if not content_type then
		return nil, err
	end

	if not content_type:match("multipart/form-data") then
		return nil, "unsupported content type"
	end

	local boundary = content_type.params.boundary
	if not boundary then
		return nil, "missing boundary"
	end

	if opts.read_all then
		local body, err = req:receive("*a")
		if not body then
			return nil, err or "failed to receive body"
		end
		return MultipartString(body, boundary)
	end

	return Multipart(req, boundary)
end

---@param req web.IRequest
---@return table?
---@return string?
function util.get_json(req)
	local content_type_str = req.headers:get("Content-Type")
	if not content_type_str then
		return nil, "missing content type"
	end

	local content_type, err = MimeType(content_type_str)
	if not content_type then
		return nil, err
	end

	if not content_type:match("application/json") then
		return nil, "unsupported content type"
	end

	local body, err = req:receive("*a")
	if not body then
		return nil, err
	end

	return json.decode_safe(body)
end

---@param res web.IResponse
---@param data any
---@return integer?
---@return string?
function util.send_json(res, data)
	res.headers:set("Content-Type", "application/json")
	return res:send(json.encode(data))
end

---@param headers web.Headers
---@param filename string
function util.set_download_file_headers(headers, filename)
	headers:set("Cache-Control", "no-cache")
	headers:set("Content-Disposition", util.encode_content_disposition({
		"attachment",
		filename = path_util.fix_illegal(filename),
	}))
	headers:set("Content-Transfer-Encoding", "binary") -- https://www.w3.org/Protocols/rfc1341/5_Content-Transfer-Encoding.html
	headers:set("Content-Type", "application/octet-stream")
end

---@param cd {[1]: string, [string]: any}
---@return string
function util.encode_content_disposition(cd)
	local parts = {cd[1]}
	for k, v in dpairs(cd) do
		if type(k) == "string" then
			local val = tostring(v)
			if k == "filename" and val:find("[^%z\1-\127]") then
				-- RFC 8187 encoding for non-ASCII filenames
				table.insert(parts, ("filename*=UTF-8''%s"):format(socket_url.escape(val)))
			else
				table.insert(parts, ("%s=%q"):format(k, val))
			end
		end
	end
	return table.concat(parts, "; ")
end

---@param s string
---@return {[1]: string, [string]: string}
function util.parse_content_disposition(s)
	---@type {[1]: string, [string]: string}
	local cd = {""}

	s = s:match("^%s*(.-)%s*$")

	---@type string?, string?
	local dtype, params = s:match("^(.-)(;.+)$")

	if not dtype then
		cd[1] = s:lower()
		return cd
	end

	---@cast params -?

	cd[1] = dtype:lower()

	for k, v in params:gmatch(";%s*([^;]-)=([^;]+)%s*") do ---@diagnostic disable-line: no-unknown
		---@cast k string
		---@cast v string
		k = k:lower()
		if k:find("%*$") then
			-- RFC 8187: parameter* (encoding specified in value)
			local real_k = k:sub(1, -2)
			local charset, lang, encoded_val = v:match("^\"?([%w%-]+)'([%w%-]*)'(.*)\"?$")
			if charset and encoded_val then
				cd[real_k] = socket_url.unescape(encoded_val)
			end
		else
			v = v:match("^\"(.+)\"$") or v
			cd[k] = socket_url.unescape(v)
		end
	end

	return cd
end

return util
