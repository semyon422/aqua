local class = require("class")

---@class http.Usecase
---@operator call: http.Usecase
local Usecase = class()

function Usecase:authorize(params)
	if not self.access then
		return "permit"
	end
	return self._access:authorize(params, self.access)
end

function Usecase:run(params)
	local ok, err = self._validator:validate(params, self.validate)
	if not ok then
		params.errors = {err}
		return "validation", params
	end

	local found = self._models:select(params, self.models)
	if not found then
		return "not_found", params
	end

	local permit, err = self:authorize(params)
	if not permit then
		params.errors = {err}
		return "forbidden", params
	end

	return self.handle(params, {
		validator = self._validator,
		models = self._models,
		access = self._access,
	})
end

return Usecase
