local class = require("class")

---@class http.UsecaseViewHandler
---@operator call: http.UsecaseViewHandler
local UsecaseViewHandler = class()

function UsecaseViewHandler:new(usecases, models, default_results, views)
	self.usecases = usecases
	self.models = models
	self.default_results = default_results
	self.views = views
end

function UsecaseViewHandler:handle(params, usecase_name, results)
	local usecase = self.usecases[usecase_name]
	local result_type, result = usecase:run(params, self.models)

	local code_view_headers = results[result_type] or self.default_results[result_type]
	if not code_view_headers then
		error("missing result handler for '" .. tostring(result_type) .. "'")
	end
	local code, view_name, headers = unpack(code_view_headers)

	local res_body
	if view_name then
		res_body = self.views[view_name](result)
	end
	if type(headers) == "function" then
		headers = headers(result)
	end

	return code or 200, headers or {}, res_body or ""
end

return UsecaseViewHandler
