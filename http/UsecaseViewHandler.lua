local class = require("class")

local UsecaseViewHandler = class()

function UsecaseViewHandler:new(default_results, usecases, usecase_repos)
	self.default_results = default_results
	self.usecases = usecases
	self.usecase_repos = usecase_repos
end

function UsecaseViewHandler:handle_params(params, usecase_name, results)
	local usecase = self.usecases[usecase_name]
	local result_type, result = usecase(params, unpack(self.usecase_repos[usecase_name]))
	local code_view = results[result_type] or self.default_results[result_type]
	local code, view = code_view[1], code_view[2]
	local res_body, headers = view(result)
	return code, headers, res_body
end

return UsecaseViewHandler
