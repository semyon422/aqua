local class = require("class")

---@class ai.router.WindowState
---@field used_percent number?
---@field updated_at number
---@alias ai.router.Windows {[integer]: {[string]: ai.router.WindowState}}

---@class ai.router.Candidate
---@field subscription ai.router.SubscriptionState
---@field model string unqualified model name
---@field upstream_model string after the subscription's permanent redirect

-- Resolves a public name to exactly one subscription. Quotas are display-only.
---@class ai.router.Router
---@operator call: ai.router.Router
---@field state ai.router.CatalogState
local Router = class()

---@param options {state: ai.router.CatalogState}
function Router:new(options)
	self.state = options.state
end

---@param public_model string
---@return string?
function Router:resolveModel(public_model)
	local target = self.state.alias_models[public_model] or public_model
	if self.state.concrete_models[target] then return target end
end

---@param public_model string
---@return ai.router.Candidate?
function Router:resolve(public_model)
	local target = self:resolveModel(public_model)
	if not target then return end
	local name, model = target:match("^([^/]+)/(.+)$")
	for _, subscription in ipairs(self.state.subscriptions) do
		if subscription.name == name and subscription.enabled and subscription.models[model] then
			return {subscription = subscription, model = model,
				upstream_model = subscription.model_redirects[model] or model}
		end
	end
end

return Router
