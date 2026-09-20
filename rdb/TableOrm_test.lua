local TableOrm = require("rdb.TableOrm")

local test = {}

---@param t testing.T
function test.begin_mode(t)
	local query
	local orm = TableOrm({
		exec = function(_, value)
			query = value
		end,
	})

	orm:begin("immediate")
	t:eq(query, "BEGIN IMMEDIATE")

	orm:begin()
	t:eq(query, "BEGIN")

	t:has_error(function()
		---@diagnostic disable-next-line: param-type-mismatch
		orm:begin("IMMEDIATE")
	end)
end

return test
