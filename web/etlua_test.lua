local etlua = require("web.etlua")

local test = {}

---@param t testing.T
function test.render_text_code_and_expressions(t)
	local fn = assert(etlua.compile("Hello <%= name %> <%- raw %><% if ok then %>!<% end %>"))

	t:eq(fn({name = "<user>", raw = "<b>", ok = true}), "Hello &lt;user&gt; <b>!")
end

---@param t testing.T
function test.closing_tag_inside_string(t)
	local fn = assert(etlua.compile([[<% local value = "%>" %><%= value %>]]))

	t:eq(fn(), "%&gt;")
end

---@param t testing.T
function test.line_comment(t)
	local fn = assert(etlua.compile([[a<% -- comment %>b]]))

	t:eq(fn(), "ab")
end

---@param t testing.T
function test.trim_newline(t)
	local fn = assert(etlua.compile("a\n<% local x = 1 -%>\nb"))

	t:eq(fn(), "a\nb")
end

---@param t testing.T
function test.parse_error_has_template_line(t)
	local parser = etlua.Parser()
	local _, err = parser:compile([[one
<% if true then %>
two]])

	t:ne(err:find("line 2", 1, true), nil)
	t:ne(err:find("if true then", 1, true), nil)
end

---@param t testing.T
function test.runtime_error_has_template_line(t)
	local parser = etlua.Parser()
	local fn = assert(parser:compile([[one
<% error("boom") %>
two]]))
	local _, err = fn({})

	t:ne(err:find("boom", 1, true), nil)
	t:ne(err:find("line 2", 1, true), nil)
	t:ne(err:find("error(\"boom\")", 1, true), nil)
end

return test
