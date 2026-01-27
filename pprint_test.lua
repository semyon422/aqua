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
		[{}] = "table key",
		nested = {a = 1, b = {}},
		nested_mt = t_with_mt,
		arr = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14},
		tbl_arr = {{}, {}, {}},
	}

	local s = pprint.dump(tbl):gsub("0x[%x]+", "0x0")

	t:eq(s, [[
<table: 0x0> {
  [false] = "bool false",
  [true] = "bool true",
  [1] = 1,
  [100] = 100,
  arr = {1, 2, 3, 4, 5, <4 more>, 10, 11, 12, 13, 14},
  ["complex\nkey"] = "val",
  escape_test = "line 1\nline 2\ttabbed\rreturn",
  nested = <table: 0x0> {
    a = 1,
    b = <table: 0x0> {},
  },
  nested_mt = <table (has mt): 0x0>,
  simple_key = "value",
  tbl_arr = {<table: 0x0> {}, <table: 0x0> {}, <table: 0x0> {}},
  ["true"] = "true",
  [<function: 0x0>] = "func key",
  [<table: 0x0>] = "table key",
}]])
end

return test
