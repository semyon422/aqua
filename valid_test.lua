local valid = require("valid")

local test = {}

---@param t testing.T
function test.index(t)
	t:tdeq({valid.index(1)}, {true})
	t:tdeq({valid.index(2)}, {true})
	t:tdeq({valid.index(0)}, {nil, "less than one"})
	t:tdeq({valid.index(1.5)}, {nil, "not an integer"})
	t:tdeq({valid.index("1")}, {nil, "not a number"})
	t:tdeq({valid.index(1 / 0)}, {nil, "infinity"})
	t:tdeq({valid.index(-1 / 0)}, {nil, "infinity"})
	t:tdeq({valid.index(0 / 0)}, {nil, "NaN"})
end

---@param t testing.T
function test.string_example(t)
	local function is_string(v)
		if type(v) == "string" then
			return true
		end
		return nil, "not a string"
	end

	t:tdeq({is_string("str")}, {true})
	t:tdeq({is_string(1)}, {nil, "not a string"})
end

---@param t testing.T
function test.string_example_no_err_msg(t)
	local function is_string(v)
		return type(v) == "string"
	end

	t:tdeq({is_string("str")}, {true})
	t:tdeq({is_string(1)}, {false})
end

---@param t testing.T
function test.optional(t)
	local function is_string(v)
		return type(v) == "string"
	end
	is_string = valid.optional(is_string)

	t:tdeq({is_string("str")}, {true})
	t:tdeq({is_string()}, {true})
	t:tdeq({is_string(1)}, {false})
end

---@param t testing.T
function test.compose(t)
	local function is_string(v)
		return type(v) == "string"
	end
	local function not_empty(v)
		return #v > 0
	end

	local is_not_empty_string = valid.compose(is_string, not_empty)

	t:tdeq({is_not_empty_string("str")}, {true})
	t:tdeq({is_not_empty_string("")}, {})
	t:tdeq({is_not_empty_string()}, {})
	t:tdeq({is_not_empty_string({})}, {})
	t:tdeq({is_not_empty_string({1})}, {})
end

---@param t testing.T
function test.flat_table(t)
	local function is_string(v)
		if type(v) == "string" then
			return true
		end
		return nil, "not a string"
	end

	local function is_string_no_err_msg(v)
		return type(v) == "string"
	end

	local is_user = valid.struct({
		name = is_string,
		desc = is_string,
		role = is_string_no_err_msg,
	})

	t:tdeq({is_user({
		name = "Name",
		desc = "Desc",
		role = "Role",
	})}, {true})

	t:tdeq({is_user({
		name = "Name",
		desc = 1,
		role = 1,
	})}, {nil, {desc = "not a string", role = true}})
end

---@param t testing.T
function test.flat_table_undefined_keys(t)
	local function is_string(v)
		return type(v) == "string"
	end

	local is_user = valid.struct({
		name = is_string,
	})

	t:tdeq({is_user({
		name = "Name",
		desc = "Desc",
	})}, {nil, {desc = false}})
end

---@param t testing.T
function test.nested_table(t)
	local function is_string(v)
		return type(v) == "string"
	end

	local is_user = valid.struct({
		name = is_string,
	}, "not a table")

	local is_user_pair = valid.struct({
		user_1 = is_user,
		user_2 = is_user,
	})

	t:tdeq({is_user_pair({
		user_1 = {name = ""},
		user_2 = {name = ""},
	})}, {true})

	t:tdeq({is_user_pair({
		user_1 = {},
		user_2 = nil,
	})}, {nil, {user_1 = {name = true}, user_2 = "not a table"}})
end

---@param t testing.T
function test.nested_table_no_err_msg(t)
	local function is_string(v)
		return type(v) == "string"
	end

	local is_user = valid.struct({
		name = is_string,
	})

	local is_user_pair = valid.struct({
		user_1 = is_user,
		user_2 = is_user,
	})

	t:tdeq({is_user_pair({
		user_1 = {},
		user_2 = nil,
	})}, {nil, {user_1 = {name = true}, user_2 = true}})
end

---@param t testing.T
function test.array_no_err_msg(t)
	local function is_string(v)
		return type(v) == "string"
	end

	local is_array = valid.array(is_string, 2)

	t:tdeq({is_array({"q", "w"})}, {true})
	t:tdeq({is_array({[10] = "w"})}, {nil, "sparse"})
	t:tdeq({is_array({"q", 2, "e"})}, {nil, "too long"})
	t:tdeq({is_array({1, 2})}, {nil, {true, true}})
	t:tdeq({is_array({"1", 2})}, {nil, {nil, true}})
	t:tdeq({is_array({1, k = 2})}, {nil, {true, k = false}})

	is_array = valid.array(valid.struct({name = is_string}), 2)
	t:tdeq({is_array({{name = 1}, 2})}, {nil, {{name = true}, true}})
end

---@param t testing.T
function test.array(t)
	local function is_string(v)
		if type(v) == "string" then
			return true
		end
		return nil, "not a string"
	end

	local is_array = valid.array(is_string, 2)

	t:tdeq({is_array({"q", "w"})}, {true})
	t:tdeq({is_array({[10] = "w"})}, {nil, "sparse"})
	t:tdeq({is_array({"q", 2, "e"})}, {nil, "too long"})
	t:tdeq({is_array({1, 2})}, {nil, {"not a string", "not a string"}})
	t:tdeq({is_array({"1", 2})}, {nil, {nil, "not a string"}})
	t:tdeq({is_array({1, k = 2})}, {nil, {"not a string", k = false}})

	is_array = valid.array(valid.struct({name = is_string}), 2)
	t:tdeq({is_array({{name = 1}, 2})}, {nil, {{name = "not a string"}, true}})
end

---@param t testing.T
function test.tuple(t)
	local function is_string(v)
		if type(v) == "string" then
			return true
		end
		return nil, "not a string"
	end

	local is_tuple = valid.tuple({is_string, is_string})

	t:tdeq({is_tuple({"q", "w"})}, {true})
	t:tdeq({is_tuple({[10] = "w"})}, {nil, {"not a string", "not a string", [10] = false}})
	t:tdeq({is_tuple({"q", 2, "e"})}, {nil, {nil, "not a string", false}})
	t:tdeq({is_tuple({"q"})}, {nil, {nil, "not a string"}})
	t:tdeq({is_tuple({1, 2})}, {nil, {"not a string", "not a string"}})
	t:tdeq({is_tuple({"1", 2})}, {nil, {nil, "not a string"}})
	t:tdeq({is_tuple({1, k = 2})}, {nil, {"not a string", "not a string", k = false}})
	t:tdeq({is_tuple({"q", 2, k = 2})}, {nil, {nil, "not a string", k = false}})
end

---@param t testing.T
function test.tuple_with_optionals(t)
	local function is_string(v)
		if type(v) == "string" then
			return true
		end
		return nil, "not a string"
	end
	is_string = valid.optional(is_string)

	local is_tuple = valid.tuple({is_string, is_string})

	t:tdeq({is_tuple({"q", "w"})}, {true})
	t:tdeq({is_tuple({[10] = "w"})}, {nil, {[10] = false}})
	t:tdeq({is_tuple({"q", 2, "e"})}, {nil, {nil, "not a string", false}})
	t:tdeq({is_tuple({"q"})}, {true})
	t:tdeq({is_tuple({1, 2})}, {nil, {"not a string", "not a string"}})
	t:tdeq({is_tuple({"1", 2})}, {nil, {nil, "not a string"}})
	t:tdeq({is_tuple({1, k = 2})}, {nil, {"not a string", nil, k = false}})
	t:tdeq({is_tuple({"q", 2, k = 2})}, {nil, {nil, "not a string", k = false}})
end

---@param t testing.T
function test.map_no_err_msg(t)
	local function is_string(v)
		return type(v) == "string"
	end
	local function is_number(v)
		return type(v) == "number"
	end

	local is_string_number_map = valid.map(is_string, is_number, 2)
	t:tdeq({is_string_number_map({a = 1})}, {true})
	t:tdeq({is_string_number_map({a = 1, b = 2})}, {true})
	t:tdeq({is_string_number_map({a = 1, b = 2, c = 3})}, {nil, "too long"})
	t:tdeq({is_string_number_map({a = 1, b = 2, [3] = 3})}, {nil, {[3] = false}})
	t:tdeq({is_string_number_map({a = "b"})}, {nil, {a = true}})
	t:tdeq({is_string_number_map({[1] = 1})}, {nil, {false}})
	t:tdeq({is_string_number_map({[1] = "a"})}, {nil, {false}})
end

---@param t testing.T
function test.map(t)
	local function is_string(v)
		if type(v) == "string" then
			return true
		end
		return nil, "not a string"
	end
	local function is_number(v)
		if type(v) == "number" then
			return true
		end
		return nil, "not a number"
	end

	local is_string_number_map = valid.map(is_string, is_number, 2)
	t:tdeq({is_string_number_map({a = 1})}, {true})
	t:tdeq({is_string_number_map({a = 1, b = 2})}, {true})
	t:tdeq({is_string_number_map({a = 1, b = 2, c = 3})}, {nil, "too long"})
	t:tdeq({is_string_number_map({a = 1, b = 2, [3] = 3})}, {nil, {[3] = "not a string"}})
	t:tdeq({is_string_number_map({a = "b"})}, {nil, {a = "not a number"}})
	t:tdeq({is_string_number_map({[1] = 1})}, {nil, {"not a string"}})
	t:tdeq({is_string_number_map({[1] = "a"})}, {nil, {"not a string"}})
end

---@param t testing.T
function test.one_of(t)
	local one_of = valid.one_of({1, "q", true})
	t:tdeq({one_of(1)}, {true})
	t:tdeq({one_of("q")}, {true})
	t:tdeq({one_of(false)}, {nil, "not one of 3 values"})
	t:tdeq({one_of("w")}, {nil, "not one of 3 values"})
end

---@param t testing.T
function test.flatten(t)
	local errs = {
		user_1 = {name = true},
		user_2 = "not a table",
		user_3 = false,
	}

	local flatten_errors = {
		"user_2 is not a table",
		"user_3 is not nil",
		"user_1.name is invalid",
	}

	t:tdeq(valid.flatten_errors(errs), flatten_errors)

	local f = valid.wrap_flatten(function(v)
		if v == 1 then return true end
		return nil, errs
	end)

	t:tdeq({f(1)}, {true})
	t:tdeq({f(0)}, {nil, flatten_errors})
end

---@param t testing.T
function test.format(t)
	local errs = {
		user_1 = {name = true},
		user_2 = "not a table",
		user_3 = false,
	}

	local format_errors = "user_2 is not a table, user_3 is not nil, user_1.name is invalid"

	t:eq(valid.format_errors(errs), format_errors)

	local f = valid.wrap_format(function(v)
		if v == 1 then return true end
		return nil, errs
	end)

	t:tdeq({f(1)}, {true})
	t:tdeq({f(0)}, {nil, format_errors})
end

---@param t testing.T
function test.equals(t)
	local a = {
		7,
		q = "a",
		w = {a = 2},
	}
	local b = {
		nil,
		8,
		q = "b",
		w = {a = 1, 1},
	}

	t:tdeq({valid.equals(a, b)}, {nil, [[missing '1', value 'q': "a", "b", value 'w.a': "2", "1", extra 'w.1', extra '2']]})
end

return test
