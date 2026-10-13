local CookieDate = require("web.http.CookieDate")

local test = {}

---@param t testing.T
function test.standard_and_legacy_dates(t)
	for _, value in ipairs({
		"Sun, 06 Nov 1994 08:49:37 GMT",
		"Sunday, 06-Nov-94 08:49:37 GMT",
		"Sun Nov  6 08:49:37 1994",
		"wrong-weekday 06 november 1994 8:49:37 ignored-zone",
	}) do
		local date = CookieDate(value)
		t:eq(date.failed, false)
		t:eq(date:get_unix_time(), 784111777)
		t:eq(tostring(date), "Sun, 06 Nov 1994 08:49:37 GMT")
	end
	t:eq(CookieDate("Thu, 01 Jan 1970 00:00:00 GMT"):get_unix_time(), 0)
	t:eq(CookieDate("Wed, 31 Dec 1969 23:59:59 GMT"):get_unix_time(), -1)
	t:eq(CookieDate("Wed, 21 Oct 2015 07:28:00 GMT"):get_unix_time(), 1445412480)
end

---@param t testing.T
function test.year_pivot_and_gregorian_calendar(t)
	t:eq(tostring(CookieDate("01 Jan 70 00:00:00")), "Thu, 01 Jan 1970 00:00:00 GMT")
	t:assert(tostring(CookieDate("01 Jan 69 00:00:00")):find("2069", 1, true))
	t:eq(CookieDate("01 Jan 1601 00:00:00"):get_unix_time(), -11644473600)
	t:eq(CookieDate("31 Dec 9999 23:59:59"):get_unix_time(), 253402300799)
	t:eq(CookieDate("29 Feb 2000 00:00:00").failed, false)
	t:eq(CookieDate("29 Feb 2400 00:00:00").failed, false)
	t:eq(CookieDate("29 Feb 1900 00:00:00").failed, true)
	t:eq(CookieDate("29 Feb 2100 00:00:00").failed, true)
end

---@param t testing.T
function test.invalid_dates(t)
	for _, value in ipairs({
		"", "garbage", "01 Jan 1970", "00 Jan 1970 00:00:00", "32 Jan 1970 00:00:00",
		"31 Apr 1970 00:00:00", "29 Feb 2023 00:00:00", "01 Jan 1600 00:00:00",
		"01 Jan 10000 00:00:00", "01 Jan 1970 24:00:00", "01 Jan 1970 00:60:00",
		"01 Jan 1970 00:00:60", "01 Jan 1970 000:00:00", "01 Jan 1970 00:00:000",
		"01 Fake 1970 00:00:00", "01 Jan 1 00:00:00",
	}) do
		local date = CookieDate(value)
		t:eq(date.failed, true)
		t:has_error(function() date:get_unix_time() end)
		t:has_error(function() return tostring(date) end)
	end
end

return test
