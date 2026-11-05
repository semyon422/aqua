---@class openai.UsageWindow
---@field used_percent number?
---@field used_tokens number?
---@field quota_tokens number?
---@field reset_at number? Unix seconds

---@alias openai.UsageWindows {[string]: openai.UsageWindow}

-- Pure decoding of Codex monitor windows. No HTTP, clocks, polling policy,
-- local estimates or completeness requirements belong to this module.
local UsageProtocol = {}

---@param value any
---@return number?
local function finiteNumber(value)
	if type(value) == "number" and value == value and math.abs(value) ~= math.huge then return value end
end

---@param usage any Raw Codex usage object, not a Responses completion's usage.
---@return openai.UsageWindows
function UsageProtocol.parseWindows(usage)
	local windows = {}
	if type(usage) ~= "table" or type(usage.rate_limit) ~= "table" then return windows end
	for name, key in pairs({five_hour = "primary_window", weekly = "secondary_window"}) do
		local window = usage.rate_limit[key]
		if type(window) == "table" then
			windows[name] = {
				used_percent = finiteNumber(window.used_percent),
				reset_at = finiteNumber(window.reset_at),
			}
		end
	end
	return windows
end

return UsageProtocol
