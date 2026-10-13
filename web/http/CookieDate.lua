local class = require("class")

-- https://www.rfc-editor.org/rfc/rfc6265#section-5.1.1

---@class web.CookieDate
---@operator call: web.CookieDate
---@field failed boolean
---@field timestamp integer?
---@field formatted string?
local CookieDate = class()

local months = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}
local weekdays = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}
local month_days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
---@type {[string]: integer}
local month_numbers = {}
for i, month in ipairs(months) do month_numbers[month:lower()] = i end

---@param year integer
---@return boolean
local function leapYear(year)
	return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

---@param year integer
---@return integer
local function daysBeforeYear(year)
	year = year - 1
	return 365 * year + math.floor(year / 4) - math.floor(year / 100) + math.floor(year / 400)
end

---@param suffix string
---@return boolean
local function validSuffix(suffix)
	return suffix == "" or suffix:match("^[^0-9]") ~= nil
end

---@param s string
function CookieDate:new(s)
	self.failed = true
	---@type integer?, integer?, integer?, integer?, integer?, integer?
	local hour, minute, second, day, month, year
	for token in s:gmatch("[^\t\32-\47\59-\64\91-\96\123-\126]+") do
		local h, m, sec, time_suffix = token:match("^([0-9][0-9]?):([0-9][0-9]?):([0-9][0-9]?)(.*)$")
		local d, day_suffix = token:match("^([0-9][0-9]?)(.*)$")
		local y, year_suffix = token:match("^([0-9][0-9][0-9]?[0-9]?)(.*)$")
		local month_number = month_numbers[token:sub(1, 3):lower()]
		if not hour and h and validSuffix(time_suffix) then
			hour, minute, second = tonumber(h), tonumber(m), tonumber(sec)
		elseif not day and d and validSuffix(day_suffix) then
			day = tonumber(d)
		elseif not month and month_number then
			month = month_number
		elseif not year and y and validSuffix(year_suffix) then
			year = tonumber(y)
		end
	end
	if not hour or not minute or not second or not day or not month or not year then return end
	if year >= 70 and year <= 99 then year = year + 1900
	elseif year <= 69 then year = year + 2000 end
	local max_day = month_days[month] + (month == 2 and leapYear(year) and 1 or 0)
	if year < 1601 or day < 1 or day > max_day or hour > 23 or minute > 59 or second > 59 then return end
	local days = daysBeforeYear(year) - daysBeforeYear(1970) + day - 1
	for i = 1, month - 1 do
		days = days + month_days[i] + (i == 2 and leapYear(year) and 1 or 0)
	end
	self.timestamp = days * 86400 + hour * 3600 + minute * 60 + second
	self.formatted = ("%s, %02d %s %04d %02d:%02d:%02d GMT"):format(
		weekdays[(days + 4) % 7 + 1], day, months[month], year, hour, minute, second)
	self.failed = false
end

---@return integer
function CookieDate:get_unix_time()
	return assert(self.timestamp, "invalid cookie date")
end

---@return string
function CookieDate:__tostring()
	return assert(self.formatted, "invalid cookie date")
end

return CookieDate
