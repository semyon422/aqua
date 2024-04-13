local Usecases = require("http.Usecases")
local Usecase = require("http.Usecase")

local test = {}

function test.all(t)
	local _usecases = {}
	_usecases.test = Usecase + {}
	_usecases.test.handle = function(self, params)
		return "ok", params
	end

	local _validator = {}
	function _validator:validate()
		return true
	end

	local _models = {}
	function _models:select()
		return true
	end

	local _access = {}
	function _access:authorize()
		return true
	end

	local usecases = Usecases(_usecases, _validator, _models, _access)

	local params = {}
	local res, _params = usecases.test:handle(params)

	t:eq(res, "ok")
	t:eq(_params, params)
end

return test
