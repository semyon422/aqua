local valid = require("valid")

local test = {}

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
	t:tdeq({is_array({[1000] = "w"})}, {nil, "sparse"})
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
	t:tdeq({is_array({[1000] = "w"})}, {nil, "sparse"})
	t:tdeq({is_array({"q", 2, "e"})}, {nil, "too long"})
	t:tdeq({is_array({1, 2})}, {nil, {"not a string", "not a string"}})
	t:tdeq({is_array({"1", 2})}, {nil, {nil, "not a string"}})
	t:tdeq({is_array({1, k = 2})}, {nil, {"not a string", k = false}})

	is_array = valid.array(valid.struct({name = is_string}), 2)
	t:tdeq({is_array({{name = 1}, 2})}, {nil, {{name = "not a string"}, true}})
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
function test.flatten(t)
	local errs = {
		user_1 = {name = true},
		user_2 = "not a table",
		user_3 = false,
	}

	t:tdeq(valid.flatten(errs), {
		"user_2 is not a table",
		"user_3 is not nil",
		"user_1.name is invalid",
	})
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
