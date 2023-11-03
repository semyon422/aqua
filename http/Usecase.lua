local class = require("class")
local UsecasePolicySet = require("UsecasePolicySet")

---@class http.Usecase
---@operator call: http.Usecase
local Usecase = class()

function Usecase:new()
	self.model_params = {}
end

function Usecase:setPolicySet(policy_set)
	self.policy_set = UsecasePolicySet()
	self.policy_set:append(policy_set)
end

function Usecase:authorize(params)
	if not self.policy_set then
		return "permit"
	end
	return self.policy_set:evaluate(params)
end

function Usecase:bindModels(model_params)
	self.model_params = model_params
end

function Usecase:select(params, models)
	for obj_name, bind_config in pairs(self.model_params) do
		local name, keys = unpack(bind_config)
		local where = {}
		for k, v in pairs(keys) do
			if type(k) ~= "string" then
				k = v
			end
			where[k] = tonumber(params[v])
		end

		local obj = models[name]:select(where)[1]
		if not obj then
			return
		end

		params[obj_name] = obj
	end

	return true
end

function Usecase:setHandler(handler)
	self.handler = handler
end

function Usecase:run(params, models)
	local found = self:select(params, models)
	if not found then
		return "not_found", params
	end

	local decision, err = self:authorize(params)
	if decision ~= "permit" then
		return "forbidden", {err}
	end

	return self.handler(params, models)
end

return Usecase
