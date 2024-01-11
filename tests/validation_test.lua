local validation = require("validation")

local test = {}

function test.all(t)
	t:assert(validation.validate(1, "number"))
	t:assert(not validation.validate(1.5, "integer"))
	t:assert(validation.validate(1.5, {"between", 1, 2}))
	t:assert(not validation.validate(2.5, {"between", 1, 2}))

	t:assert(validation.validate("w", {"one_of", "q", "w", "e"}))
	t:assert(validation.validate({a = "q", b = {c = "w"}}, {
		a = "string",
		b = {
			c = {"string"},
		},
	}))
	t:assert(validation.validate({"q", "w", "e"}, {"array_of", {"string"}}))
	t:assert(validation.validate("w", {"*", "string", {"#", 1}}))
	t:assert(not validation.validate("w", {"*", "string", {"#", 2}}))
end

return test
