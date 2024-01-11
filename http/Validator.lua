local class = require("class")
local validation = require("validation")

local Validator = class()

function Validator:validate(params, schema)
	return validation.validate(params, schema)
end

return Validator
