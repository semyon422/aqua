local stbl = require("stbl")

local test = {}

---@param t testing.T
function test.all(t)
	local tbl = {
		1,
		2,
		nil,
		1e+30,
		[1.5] = 2.5,
		a = "qwe",
		t = {[2] = {}},
		["true"] = false,
		["\n"] = "\a \b \f \n \r \t \v \\ \" \' \0 \1",
	}
	tbl.ref = tbl
	local s = [[{1,2,nil,1e+30,[1.5]=2.5,["\n"]="\a \b \f \n \r \t \v \\ \" \' \0 \001",a="qwe",ref=nil,t={nil,{}},["true"]=false}]]

	t:eq(stbl.encode(tbl), s)

	tbl.ref = nil
	t:tdeq(stbl.decode(s), tbl)

	s = [[ {
		1 , 2 , nil , 1e+30 , [ 1.5 ] = 2.5 ,
		[ "\n" ] = "\a \b \f \n \r \t \v \\ \" \' \0 \001",
		a = "qwe" , ref = nil , t = { nil , { } } , [ "true" ] = false
	} ]]
	t:tdeq(stbl.decode(s), tbl)

	t:eq(stbl.decode("0x1p+2"), 4)

	t:has_error(stbl.encode, {[true] = 1})
	t:has_error(stbl.encode, {[{}] = 1})

	t:has_error(stbl.decode, "{,}")
	t:has_error(stbl.decode, "{")
	t:has_error(stbl.decode, [[ "no end ]])
end

return test
