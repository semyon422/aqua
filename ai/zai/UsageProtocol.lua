-- Pure decoding of the Z.ai monitor's already-unwrapped `data` object.
-- Only known unit/number pairs identify windows; quota policy stays outside.
local UsageProtocol = {}

---@param value any
---@return number?
local function finiteNumber(value)
	if type(value) == "number" and value == value and math.abs(value) ~= math.huge then return value end
end

---@param data any Monitor data, not the RPC envelope containing `data`.
---@return openai.UsageWindows
function UsageProtocol.parseWindows(data)
	local windows = {}
	if type(data) ~= "table" or type(data.limits) ~= "table" then return windows end
	for _, limit in ipairs(data.limits) do
		if type(limit) == "table" then
			local name
			if limit.unit == 3 and limit.number == 5 then
				name = "five_hour"
			elseif limit.unit == 6 and limit.number == 1 then
				name = "weekly"
			end
			if name then
				local reset = finiteNumber(limit.nextResetTime)
				windows[name] = {
					used_percent = finiteNumber(limit.percentage),
					used_tokens = finiteNumber(limit.currentValue),
					quota_tokens = finiteNumber(limit.usage),
					reset_at = reset and math.floor(reset / 1000) or nil,
				}
			end
		end
	end
	return windows
end

return UsageProtocol
