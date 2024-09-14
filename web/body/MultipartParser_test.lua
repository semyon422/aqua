local http_util = require("http_util")
local MultipartParser = require("web.body.MultipartParser")

local test = {}

function test.basic(t)
	local body = http_util.multipart_form_data({
		{"data1", name = "name1", filename = "filename1"},
		{"data2", name = "name2", filename = "filename2"},
	})

	local boundary = "------------------------d67fe448c18233b3"
	local parser = MultipartParser({
		["Content-Type"] = "multipart/form-data; boundary=" .. boundary
	})

	local parts = parser:read(body)

	t:tdeq(parts, {
		'Content-Disposition: form-data; name="name1"; filename="filename1"\r\nContent-Type: application/octet-stream\r\n\r\ndata1',
		'Content-Disposition: form-data; name="name2"; filename="filename2"\r\nContent-Type: application/octet-stream\r\n\r\ndata2',
	})
end

return test
