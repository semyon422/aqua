local sql_util = require("rdb.sql_util")
local table_util = require("table_util")

local test = {}

---@param t testing.T
function test.all(t)
	local Roles = {
		user = 0,
		admin = 1,
	}

	local types = {
		is_admin = "boolean",
		role = {
			decode = function(v) return table_util.keyof(Roles, v) end,
			encode = function(k) return Roles[k] end,
		},
	}

	local t_from_db = {
		is_admin = true,
		role__in = {"user", "admin"},
		role__isnull = true,
		{name = "admin"},
	}
	local t_for_db = {
		is_admin = 1,
		role__in = {0, 1},
		role__isnull = true,
		{name = "admin"},
	}
	t:tdeq(sql_util.conditions_for_db(t_from_db, types), t_for_db)

	t:eq(sql_util.conditions({t__isnull = true}), "(`t` IS NULL)")
	t:eq(sql_util.conditions({t__isnull = false}), "")
	t:has_error(sql_util.conditions, {true})

	t:tdeq(sql_util.split_sql("'hello''wor;ld'; 'hi';    "), {"'hello''wor;ld';", " 'hi';"})
end

return test
