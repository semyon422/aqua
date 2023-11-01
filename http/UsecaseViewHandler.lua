local class = require("class")

local UsecaseViewHandler = class()

function UsecaseViewHandler:new(usecases, models, default_results, views)
	self.usecases = usecases
	self.models = models
	self.default_results = default_results
	self.views = views
end

function UsecaseViewHandler:handle_params(params, usecase_name, results)
	local usecase = self.usecases[usecase_name]
	local result_type, result = usecase:run(params, self.models)
	local code_view = results[result_type] or self.default_results[result_type]
	local code, view_name, view_params = unpack(code_view)
	local res_body, headers = self.views[view_name](result, view_params)
	return code, headers, res_body
end

return UsecaseViewHandler
