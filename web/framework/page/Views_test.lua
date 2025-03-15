local Views = require("web.framework.page.Views")

local test = {}

function test.basic(t)
	local tpls = {}

	function tpls.aaa(params)
		return "a" .. params.view({text = "d"}):render("bbb")
	end
	function tpls.bbb(params)
		return "b" .. params.msg .. params.text
	end

	local views = Views(tpls)

	local res = views:render("aaa", {msg = "c"})
	t:eq(res, "abcd")
end

function test.render(t)
	local tpls = {}

	function tpls.aaa(params)
		return "[" .. params.inner .. "]"
	end
	function tpls.bbb(params)
		return "{" .. params.inner .. "}"
	end
	function tpls.ccc(params)
		return params.msg
	end

	local views = Views(tpls)

	local res = views:render({aaa = {bbb = "ccc"}}, {msg = "a"})
	t:eq(res, "[{a}]")
end

return test
