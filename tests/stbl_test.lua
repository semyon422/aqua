local stbl = require("stbl")

local test = {}

function test.all(t)
	local tbl = {
		1,
		2,
		nil,
		math.huge,
		[-math.huge] = 0 / 0,
		a = "qwe",
		t = {[2] = {}},
		["true"] = false,
		["\n"] = "\a \b \f \n \r \t \v \\ \" \' \0",
	}
	local s = [[{1,2,nil,1/0,[-1/0]=0/0,["\n"]="\a \b \f \n \r \t \v \\ \" \' \0",a="qwe",t={nil,{}},["true"]=false}]]

	t:eq(stbl.encode(tbl), s)
	t:tdeq(stbl.decode(s), tbl)

	-- t:has_error(stbl.encode, 0ll)
	t:has_error(stbl.encode, {[true] = 1})
	t:has_error(stbl.decode, "{,}")
end

return test
