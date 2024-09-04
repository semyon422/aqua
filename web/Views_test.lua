local Views = require("web.Views")

local test = {}

function test.basic(t)
	local _views = {}

	function _views.aaa(params)
		return "a" .. params.view({text = "d"}):render("bbb")
	end
	function _views.bbb(params)
		return "b" .. params.msg .. params.text
	end

	local views = Views(_views, {})

	local res = views.aaa({msg = "c"})
	t:eq(res, "abcd")
end

function test.render(t)
	local _views = {}

	function _views.aaa(params)
		return "[" .. params.inner .. "]"
	end
	function _views.bbb(params)
		return "{" .. params.inner .. "}"
	end
	function _views.ccc(params)
		return params.msg
	end

	local views = Views(_views, {})

	local res = views:render({aaa = {bbb = "ccc"}}, {msg = "a"})
	t:eq(res, "[{a}]")
end

return test
