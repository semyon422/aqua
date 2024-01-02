local Views = require("http.Views")

local test = {}

function test.all(t)
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

return test
