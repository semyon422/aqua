local class = require("class")

---@class ai.router.WindowState
---@field used_percent number?
---@field updated_at number
---@alias ai.router.Windows {[integer]: {[string]: ai.router.WindowState}}

---@class ai.router.Candidate
---@field channel ai.router.ChannelState
---@field model string unqualified model name
---@field upstream_model string after the channel's permanent redirect

-- Resolves a public name to exactly one channel. Quotas are display-only.
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
	for _, channel in ipairs(self.state.channels) do
		if channel.name == name and channel.enabled and channel.models[model] then
			return {channel = channel, model = model,
				upstream_model = channel.model_redirects[model] or model}
		end
	end
end

return Router
