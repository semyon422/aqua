local class = require("class")
local Test = require("testing.Test")

---@alias testing.TFunction fun(t: testing.T)
---@alias testing.TModule {[string]: testing.TFunction}

---@class testing.TestFileResult
---@field path string
---@field tests integer
---@field time number

---@class testing.TestError
---@field file string
---@field line integer
---@field method string?
---@field detail string

---@class testing.TestResult
---@field files testing.TestFileResult[]
---@field errors testing.TestError[]
---@field total integer
---@field fail integer

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
---@param path string
---@param method_pattern string?
function Testing:testMod(tmod, path, method_pattern)
	local t = self.t
	t.name = nil
	t.path = path
	local errors = #t
	for method, tf in pairs(tmod) do
		if (not method_pattern or method:match(method_pattern)) and not method:match("^__") then
			t.name = method
			local ok, err = xpcall(tf, debug.traceback, t)
			if not ok then
				t:expected_assert(false, "crash", err, nil, "unexpected error")
			end
			if errors ~= #t then
				errors = #t
				self.fail = self.fail + 1
			end
			self.total = self.total + 1
		end
	end
	t.path = nil
end

--- Parse a single error line into a structured error.
---@param line string
---@return testing.TestError
function Testing:_parse_error(line)
	local file, lnum, msg = line:match("^(.+):(%d+):(.*)$")
	if file and lnum then
		local method = msg:match("^%s*%(([%w_]+)%)")
		return {file = file, line = tonumber(lnum), method = method, detail = line}
	end
	return {file = "?", line = 0, method = nil, detail = line}
end

--- Run all matching test files and return structured results.
--- When `on_file_start` is given it is called before each file runs.
--- When `on_file_end` is given it is called after each file completes (file results are not collected).
---@param file_pattern string?
---@param method_pattern string?
---@param on_file_start fun(path: string)?: called before each file runs
---@param on_file_end fun(file_result: testing.TestFileResult)?: called after each file; when absent results are collected
---@return testing.TestResult
function Testing:_run(file_pattern, method_pattern, on_file_start, on_file_end)
	self.total = 0
	self.fail = 0
	for i = #self.t, 1, -1 do
		table.remove(self.t, i)
	end

	---@type testing.TestFileResult[]
	local files = {}

	for path in self.tio:iterFiles("") do
		if path:match("_test%.lua$") and (not file_pattern or path:match(file_pattern)) then
			if on_file_start then on_file_start(path) end

			local start_time = self.tio:getTime()
			local tmod = self.tio:dofile(path)
			local file_result = {path = path, tests = 0, time = 0}
			if tmod and (not tmod.__check or tmod.__check(self.t)) then
				local total = self.total
				self:testMod(tmod, path, method_pattern)
				file_result.tests = self.total - total
			end
			file_result.time = self.tio:getTime() - start_time

			if on_file_end then
				on_file_end(file_result)
			else
				table.insert(files, file_result)
			end
		end
	end

	---@type testing.TestError[]
	local errors = {}
	for _, line in ipairs(self.t) do
		table.insert(errors, self:_parse_error(line))
	end

	return {files = files, errors = errors, total = self.total, fail = self.fail}
end

---@param file_pattern string?
---@param method_pattern string?
function Testing:test(file_pattern, method_pattern)
	local tio = self.tio

	self:_run(
		file_pattern,
		method_pattern,
		function(path)
			tio:writeStdout(path)
			tio:writeStdout(": ")
		end,
		function(file_result)
			tio:writeStdout(file_result.tests)
			tio:writeStdout((" - %0.3fs\n"):format(file_result.time))
		end
	)

	for _, line in ipairs(self.t) do
		tio:writeStdout(line .. "\n")
	end

	if self.fail == 0 then
		tio:writeStdout(("OK: %s\n"):format(self.total))
	else
		tio:writeStdout(("FAIL: %d / %d\n"):format(self.fail, self.total))
	end
end

--- Run tests and output results as a single JSON object to stdout.
---@param file_pattern string?
---@param method_pattern string?
function Testing:test_json(file_pattern, method_pattern)
	local result = self:_run(file_pattern, method_pattern)
	local json = require("json")
	self.tio:writeStdout(json.encode(result))
	self.tio:writeStdout("\n")
end

return Testing
