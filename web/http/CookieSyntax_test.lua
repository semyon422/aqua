local CookieSyntax = require("web.http.CookieSyntax")

local test = {}

---@param t testing.T
function test.ascii_grammar(t)
	local separators = '()<>@,;:\\"/[]?={} '
	for byte = 0, 255 do
		local char = string.char(byte)
		t:eq(CookieSyntax.validName(char), byte >= 33 and byte <= 126 and not separators:find(char, 1, true))
		t:eq(CookieSyntax.validValue(char), byte >= 33 and byte <= 126 and byte ~= 34 and byte ~= 44 and byte ~= 59 and byte ~= 92)
		t:eq(CookieSyntax.validAttributeValue(char), byte >= 32 and byte <= 126 and byte ~= 59)
	end
	t:eq(CookieSyntax.validName(""), false)
	t:eq(CookieSyntax.validValue(""), true)
	t:eq(CookieSyntax.validValue('""'), true)
	t:eq(CookieSyntax.validValue('"a=+/%20"'), true)
	t:eq(CookieSyntax.validValue('"a b"'), false)
	t:eq(CookieSyntax.validValue('"a'), false)
end

---@param t testing.T
function test.domain_grammar(t)
	for _, domain in ipairs({"example.com", "localhost", "127.0.0.1", "xn--e1afmkfd.xn--p1ai", "a-b.1example"}) do
		t:eq(CookieSyntax.validDomain(domain), true)
	end
	for _, domain in ipairs({"", ".example.com", "example.com.", "a..b", "a_b", "-a.com", "a-.com", "a/b", "пример.рф", string.rep("a", 64) .. ".com", string.rep("a.", 127) .. "a"}) do
		t:eq(CookieSyntax.validDomain(domain), false)
	end
end

return test
