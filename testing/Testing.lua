local class = require("class")
local Test = require("testing.Test")

---@alias testing.TFunction fun(t: testing.T)
---@alias testing.TModule {[string]: testing.TFunction}

---@class testing.Testing
---@operator call: testing.Testing
local Testing = class()

Testing.total = 0
Testing.fail = 0

---@param tio testing.ITestingIO
function Testing:new(tio)
	self.tio = tio
	self.t = Test()
end

---@type string[]
Testing.blacklist = {}

---@param tmod testing.TModule
---@param method_pattern string?
function Testing:testMod(tmod, method_pattern)
	local t = self.t
	t.name = nil
	local errors = #t
	for method, tf in pairs(tmod) do
		if not method_pattern or method:match(method_pattern) then
			t.name = method
			tf(t)
			if errors ~= #t then
				errors = #t
				self.fail = self.fail + 1
			end
			self.total = self.total + 1
		end
	end
end

---@param file_pattern string?
---@param method_pattern string?
function Testing:test(file_pattern, method_pattern)
	local tio = self.tio

	for path in tio:iterFiles("") do
		if path:match("_test%.lua$") and (not file_pattern or path:match(file_pattern)) then
			tio:writeStdout(path)

			local start_time = tio:getTime()
			local tmod = tio:dofile(path)
			if tmod then
				self:testMod(tmod, method_pattern)
			end
			local dt = tio:getTime() - start_time

			tio:writeStdout((": %0.3fs\n"):format(dt))
		end
	end

	for _,  line in ipairs(self.t) do
		tio:writeStdout(line .. "\n")
	end

	if self.fail == 0 then
		tio:writeStdout(("OK: %s\n"):format(self.total))
	else
		tio:writeStdout(("FAIL: %d / %d\n"):format(self.fail, self.total))
	end
end

return Testing
