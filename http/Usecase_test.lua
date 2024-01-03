local Usecases = require("http.Usecases")

local test = {}

function test.all(t)
	local _usecases = {}
	_usecases.test = {
		validate = {},
		models = {},
		access = {},
		handle = function(params, models)
			return "permit", params
		end,
	}

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
	local res, _params = usecases.test:run(params)

	t:eq(res, "permit")
	t:eq(_params, params)
end

return test
