local class = require("class")
local deco = require("deco")
local ClassDecorator = require("typecheck.ClassDecorator")
local TypeDecorator = require("typecheck.TypeDecorator")
local typecheck = require("typecheck")

local test = {}

---@class deco_test.MarkerDecorator: deco.FunctionDecorator
---@operator call: deco_test.MarkerDecorator
local MarkerDecorator = class(deco.FunctionDecorator)

---@param func_name string
---@return string
function MarkerDecorator:func_end(func_name)
	return ("mark(%q)"):format(func_name)
end

---@param source string
---@param decorators deco.Decorator[]
---@return string
local function process_with(source, decorators)
	local previous = deco.decorators
	deco.decorators = decorators
	local ok, result = pcall(deco.process, source)
	deco.decorators = previous
	assert(ok, result)
	return result
end

---@param s string
---@return integer
local function count_newlines(s)
	local _, count = s:gsub("\n", "")
	return count
end

---@param t testing.T
function test.structural_function_boundaries(t)
	local source = [=[
local text = [[function fake()
end]]

local function outer(
)
	local inner = function()
		if true then
			return 0ull
		end
	end -- inner
	return 0b1 + 1i
end -- outer
]=]
	local expected = [=[
local text = [[function fake()
end]]

local function outer(
)
	local inner = function()
		if true then
			return 0ull
		end
	end mark("inner") -- inner
	return 0b1 + 1i
end mark("outer") -- outer
]=]

	local result = process_with(source, {MarkerDecorator()})
	t:eq(result, expected)
	t:eq(count_newlines(result), count_newlines(source))
	t:assert(loadstring(result))
end

---@param t testing.T
function test.multiline_method_declaration(t)
	local source = [[
function mod.Class:method(
	value
)
	return value
end
]]
	local expected = [[
function mod.Class:method(
	value
)
	return value
end mark("mod.Class:method")
]]

	t:eq(process_with(source, {MarkerDecorator()}), expected)
end

---@param t testing.T
function test.type_annotations_are_local_to_function(t)
	---@type boolean
	local strict = typecheck.strict
	typecheck.strict = false

	local source = [[
---@param skipped number
---@nocheck
local function unchecked(skipped)
	return skipped
end

local function plain()
	return true
end

	---@param value number
	---@return number
	local function checked(value)
		return value
	end
]]
	local expected = source:gsub(
		"end\n$",
		[[end checked = require("typecheck").decorate(checked, "checked(value: number): number")
]]
	)

	local result = process_with(source, {TypeDecorator()})
	typecheck.strict = strict
	t:eq(result, expected)
end

---@param t testing.T
function test.class_annotation_uses_local_declaration(t)
	local source = [[
	---@class example.MyClass
	local MyClass = class()
]]
	local expected = [[
	---@class example.MyClass
	local MyClass = class() require("typecheck").register_class("example.MyClass", MyClass)
]]

	t:eq(process_with(source, {ClassDecorator()}), expected)
end

---@param t testing.T
function test.decorator_order_is_preserved(t)
	---@class deco_test.NamedMarker: deco.FunctionDecorator
	---@operator call: deco_test.NamedMarker
	local NamedMarker = class(deco.FunctionDecorator)

	---@param name string
	function NamedMarker:new(name)
		self.name = name
	end

	---@return string
	function NamedMarker:func_end()
		return self.name
	end

	local source = "local function f() end"
	local expected = "local function f() end first second"
	t:eq(process_with(source, {NamedMarker("first"), NamedMarker("second")}), expected)
end

return test
