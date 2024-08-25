local class = require("class")
local Test = require("testing.Test")

---@alias testing.TFunction fun(t: testing.T)
---@alias testing.TModule {[string]: testing.TFunction}

---@class testing.Testing
---@operator call: testing.Testing
local Testing = class()

---@param tio testing.ITestingIO
function Testing:new(tio)
	self.tio = tio
end

---@type string[]
Testing.blacklist = {}

---@param tmod testing.TModule
---@param t testing.T
---@param method_pattern string?
local function run_tests(tmod, t, method_pattern)
	local errors = #t
	for method, tf in pairs(tmod) do
		if not method_pattern or method:match(method_pattern) then
			tf(t)
			if errors ~= #t then
				errors = #t
				t.fail = t.fail + 1
			end
			t.total = t.total + 1
		end
	end
end

---@param file_pattern string?
---@param method_pattern string?
function Testing:test(file_pattern, method_pattern)
	local tio = self.tio
	local t = Test()

	for path in tio:iterFiles("") do
		if path:match("_test%.lua$") and (not file_pattern or path:match(file_pattern)) then
			tio:writeStdout(path)

			local start_time = tio:getTime()
			local mod = tio:dofile(path)
			if mod then
				run_tests(mod, t, method_pattern)
			end
			local dt = tio:getTime() - start_time

			tio:writeStdout((": %0.3fs\n"):format(dt))
		end
	end

	for _,  line in ipairs(t) do
		tio:writeStdout(line)
	end

	if t.fail == 0 then
		tio:writeStdout(("OK: %s\n"):format(t.total))
	else
		tio:writeStdout(("FAIL: %d / %d\n"):format(t.fail, t.total))
	end
end

return Testing
