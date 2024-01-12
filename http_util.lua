local socket_url = require("socket.url")

local http_util = {}

---@param t table
---@return string
function http_util.encode_query_string(t)
	local i = 0
	local buf = {}
	for k, v in pairs(t) do
		if v ~= false then
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
	end
	buf[i] = nil
	return table.concat(buf)
end

---@param s string
---@return table
function http_util.decode_query_string(s)
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

local boundary = "------------------------d67fe448c18233b3"

---@param files table
---@return string
---@return table
function http_util.multipart_form_data(files)
	local body = {}
	for _, file in ipairs(files) do
		table.insert(body, "--" .. boundary)
		table.insert(body, ("Content-Disposition: form-data; name=%q; filename=%q"):format(
			file.name, file.filename or file.name
		))
		table.insert(body, "Content-Type: application/octet-stream")
		table.insert(body, "")
		table.insert(body, file[1])
	end
	table.insert(body, "--" .. boundary .. "--")
	table.insert(body, "")

	body = table.concat(body, "\r\n")

	local headers = {
		["Content-Length"] = #body,
		["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
	}

	return body, headers
end

function http_util.parse_multipart_form_data(body, boundary)
	local parts = {}

	for part in body:gmatch("%-%-" .. boundary .. "\r?\n(.-)%-%-" .. boundary) do
		table.insert(parts, part)
	end

	return parts
end

-- https://www.rfc-editor.org/rfc/rfc2183.html

---@param s string
---@return table
function http_util.parse_content_disposition(s)
	local cd = {}

	s = s:match("^%s*(.-)%s*$")

	local dtype, params = s:match("^(.-)(;.+)$")

	if not dtype then
		cd.type = s
		return cd
	end

	for k, v in params:gmatch(";%s*([^;]-)=([^;]+)%s*") do
		v = socket_url.unescape(v:match("^\"(.+)\"") or v)
		cd[k] = v
	end

	return cd
end

return http_util
