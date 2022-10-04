local http_util = {}

local escape = require("socket.url").escape

-- from lapis
function http_util.encode_query_string(t, sep)
	if sep == nil then
		sep = "&"
	end
	local i = 0
	local buf = {}
	for k, v in pairs(t) do
		local continue = false
		repeat
			if type(k) == "number" and type(v) == "table" then
				k, v = v[1], v[2]
				if v == nil then
					v = true
				end
			end
			if v == false then
				continue = true
				break
			end
			buf[i + 1] = escape(k)
			if v == true then
				buf[i + 2] = sep
				i = i + 2
			else
				buf[i + 2] = "="
				buf[i + 3] = escape(v)
				buf[i + 4] = sep
				i = i + 4
			end
			continue = true
		until true
		if not continue then
			break
		end
	end
	buf[i] = nil
	return table.concat(buf)
end

local boundary = "------------------------d67fe448c18233b3"

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

return http_util
