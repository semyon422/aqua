local MimeType = require("web.http.MimeType")

local test = {}

---@param t testing.T
function test.basic(t)
	t:eq(tostring(MimeType("text/html")), "text/html")
	t:eq(tostring(MimeType("application/xml; q=0.9")), "application/xml; q=0.9")
	t:eq(tostring(MimeType("multipart/form-data; boundary=----qwerty")), "multipart/form-data; boundary=----qwerty")

	t:assert(not MimeType("text html"))

	t:assert(MimeType("application/xml; q=0.9"):match("application/xml"))
	t:assert(not MimeType("application/xml; q=0.9"):match("application/xml", true))
	t:assert(not MimeType("application/xml"):match("application/xml; q=0.9"))
end

return test
