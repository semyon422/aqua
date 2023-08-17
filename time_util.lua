local time_util = {}

-- https://leafo.net/lapis/reference/utilities.html

---@param later number
---@param sooner number
---@return table
function time_util.date_diff(later, sooner)
	if later < sooner then
		sooner, later = later, sooner
	end
	local diff = later - sooner
	local times = {}
	local days = math.floor(diff / 86400)
	if days >= 365 then
		local years = math.floor(days / 365)
		times.years = years
		table.insert(times, {
			"years",
			years
		})
		diff = diff - years * 365 * 86400
		days = days - (years * 365)
	end
	if days >= 1 then
		times.days = days
		table.insert(times, {
			"days",
			days
		})
		diff = diff - days * 86400
	end
	local hours = math.floor(diff / 3600)
	if hours >= 1 then
		times.hours = hours
		table.insert(times, {
			"hours",
			hours
		})
		diff = diff - hours * 3600
	end
	local minutes = math.floor(diff / 60)
	if minutes >= 1 then
		times.minutes = minutes
		table.insert(times, {
			"minutes",
			minutes
		})
		diff = diff - minutes * 60
	end
	local seconds = math.floor(diff)
	if seconds >= 1 or not next(times) then
		times.seconds = seconds
		table.insert(times, {
			"seconds",
			seconds
		})
		diff = diff - seconds
	end
	return times
end

---@param time number
---@return table
function time_util.time_ago(time)
	return time_util.date_diff(os.time(), time)
end

local singular = {
	years = "year",
	days = "day",
	hours = "hour",
	minutes = "minute",
	seconds = "second"
}

---@param time number
---@param parts number?
---@param suffix string?
---@return string
function time_util.time_ago_in_words(time, parts, suffix)
	if not parts then
		parts = 1
	end
	if not suffix then
		suffix = "ago"
	end
	local ago = type(time) == "table" and time or time_util.time_ago(time)
	local out = ""
	local i = 1
	while parts > 0 do
		parts = parts - 1
		local segment = ago[i]
		i = i + 1
		if not segment then
			break
		end
		local val = segment[2]
		local word = val == 1 and singular[segment[1]] or segment[1]
		if #out > 0 then
			out = out .. ", "
		end
		out = out .. val .. " " .. word
	end
	if suffix and suffix ~= "" then
		return out .. " " .. suffix
	end
	return out
end

---@param time number
---@param decimals number?
---@return string
function time_util.format(time, decimals)
	local sign = time >= 0 and "" or "-"
	time = math.abs(time)

	local hours = math.floor(time / 3600)
	local minutes = math.floor(time % 3600 / 60)
	local seconds = math.floor(time % 60)

	local s
	if time >= 3600 then
		s = ("%d:%02d:%02d"):format(hours, minutes, seconds)
	else
		s = ("%02d:%02d"):format(minutes, seconds)
	end

	if decimals then
		s = s .. ("%0." .. decimals .. "f"):format(time % 1):sub(2)
	end

	return sign .. s
end

return time_util
