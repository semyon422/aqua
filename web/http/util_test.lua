local util = require("web.http.util")
local test = {}

---@param t testing.T
function test.parse_content_disposition(t)
	local s = "attachment; filename=\"test.zip\"; size=123"
	local cd = util.parse_content_disposition(s)
	t:eq(cd[1], "attachment")
	t:eq(cd.filename, "test.zip")
	t:eq(cd.size, "123")

	local s2 = "inline"
	local cd2 = util.parse_content_disposition(s2)
	t:eq(cd2[1], "inline")

	local s3 = "form-data; name=\"file\"; filename=\"photo.jpg\""
	local cd3 = util.parse_content_disposition(s3)
	t:eq(cd3[1], "form-data")
	t:eq(cd3.name, "file")
	t:eq(cd3.filename, "photo.jpg")

	-- RFC 8187
	local s4 = "attachment; filename*=UTF-8''%d1%82%d0%b5%d1%81%d1%82%2ezip"
	local cd4 = util.parse_content_disposition(s4)
	t:eq(cd4[1], "attachment")
	t:eq(cd4.filename, "тест.zip")
end

---@param t testing.T
function test.encode_content_disposition(t)
	local cd = {"attachment", filename = "test.zip", size = 123}
	local s = util.encode_content_disposition(cd)
	-- dpairs sorts alphabetically: filename, size
	t:eq(s, "attachment; filename=\"test.zip\"; size=\"123\"")

	local cd2 = {"form-data", name = "file"}
	local s2 = util.encode_content_disposition(cd2)
	t:eq(s2, "form-data; name=\"file\"")

	-- RFC 8187
	local cd3 = {"attachment", filename = "тест.zip"}
	local s3 = util.encode_content_disposition(cd3)
	t:eq(s3, "attachment; filename*=UTF-8''%d1%82%d0%b5%d1%81%d1%82%2ezip")
end

return test
