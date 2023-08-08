local error_code = require("bass.error_code")

return function(condition)
	if not condition then
		error(error_code())
	end
end
