local tablecheck = require("typecheck.tablecheck")

local test = {}

function test.all(t)
	local tt = tablecheck([[(
		a: number,
		b: string,
		c: string?
	)]])

	tt({
		a = 1,
		b = "",
	})
	tt({
		a = 1,
		b = "",
		c = "",
	})

	t:has_error(tt, {
		a = 1,
		b = "",
		c = 1,
	})
	t:has_error(tt, {
		a = "",
		b = "",
	})
	t:has_error(tt, {
		a = 1,
	})
end

return test
