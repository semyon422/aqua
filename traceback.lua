local traceback = {}

---@class traceback.Frame
---@field name string?
---@field namewhat string
---@field source string
---@field short_src string
---@field linedefined integer
---@field lastlinedefined integer
---@field currentline integer
---@field what string

---@class traceback.Captured
---@field message any
---@field frames traceback.Frame[]

---@param ... any
---@return thread?, any, integer
local function parse_args(...)
	local n = select("#", ...)
	local first = select(1, ...)
	if type(first) == "thread" then
		local level = select(3, ...)
		return first, select(2, ...), tonumber(level) or 1
	end
	local level = select(2, ...)
	if n < 2 then
		level = 1
	end
	return nil, first, tonumber(level) or 1
end

---@param ... any
---@return traceback.Captured
function traceback.capture(...)
	local co, message, level = parse_args(...)

	---@type traceback.Frame[]
	local frames = {}
	local i = co and level or (level + 1)

	while true do
		---@type debuginfo
		local info
		if co then
			info = debug.getinfo(co, i, "nSlu")
		else
			info = debug.getinfo(i, "nSlu")
		end
		if not info then
			break
		end
		frames[#frames + 1] = {
			name = info.name,
			namewhat = info.namewhat,
			source = info.source,
			short_src = info.short_src,
			linedefined = info.linedefined,
			lastlinedefined = info.lastlinedefined,
			currentline = info.currentline,
			what = info.what,
		}
		i = i + 1
	end

	return {
		message = message,
		frames = frames,
	}
end

return traceback
