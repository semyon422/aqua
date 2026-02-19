local pprint = require("pprint")

local test = {}

---@param t testing.T
function test.all(t)
	local mt = {__tostring = function() return "HIDDEN" end}
	local t_with_mt = setmetatable({}, mt)

	local tbl = {
		[true] = "bool true",
		[false] = "bool false",
		[100] = 100,
		[1] = 1,
		simple_key = "value",
		["complex\nkey"] = "val",
		["true"] = "true",
		escape_test = "line 1\nline 2\ttabbed\rreturn",
		[function() end] = "func key",
		func = function() end,
		[{}] = "table key",
		nested = {a = 1, b = {}},
		nested_mt = t_with_mt,
		arr = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14},
		tbl_arr = {{}, {t = 1}, {}},
	}
	tbl.ref = tbl

	pprint.colored = false
	local s = pprint.dump(tbl):gsub("0x[%x]+", "0x0"):gsub("aqua/pprint_test%.lua:%d+", "aqua/pprint_test.lua:0")
	pprint.colored = true

	t:eq(s, [[
<table: 0x0> {
  [false] = "bool false",
  [true] = "bool true",
  [1] = 1,
  [100] = 100,
  arr = {1, 2, 3, 4, 5, <4 more>, 10, 11, 12, 13, 14},
  ["complex\nkey"] = "val",
  escape_test = "line 1\nline 2\ttabbed\rreturn",
  func = <function: aqua/pprint_test.lua:0 | 0x0>,
  nested = <table: 0x0> {
    a = 1,
    b = <table: 0x0> {},
  },
  nested_mt = <table (has mt): 0x0>,
  ref = <table (recursive): 0x0>,
  simple_key = "value",
  tbl_arr = {<table: 0x0> {}, <table: 0x0> {
    t = 1,
  }, <table: 0x0> {}},
  ["true"] = "true",
  [<function: 0x0>] = "func key",
  [<table: 0x0>] = "table key",
}]])
end

---@param t testing.T
function test.name(t)
	local MyClass = {__name = "MyClass"}
	local instance = setmetatable({foo = "bar"}, MyClass)
	MyClass.__index = MyClass

	pprint.colored = false
	local s = pprint.dump(instance):gsub("0x[%x]+", "0x0")
	pprint.colored = true

	t:eq(s, [[
<MyClass: 0x0> {
  foo = "bar",
}]])

	local empty = setmetatable({}, {__name = "EmptyClass"})
	pprint.colored = false
	s = pprint.dump(empty):gsub("0x[%x]+", "0x0")
	pprint.colored = true
	t:eq(s, [[<EmptyClass: 0x0> {}]])

	local nested = {
		obj = instance
	}
	pprint.colored = false
	s = pprint.dump(nested):gsub("0x[%x]+", "0x0")
	pprint.colored = true
	t:eq(s, [[
<table: 0x0> {
  obj = <MyClass: 0x0>,
}]])
end

return test
