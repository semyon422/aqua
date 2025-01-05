local ip = require("web.ip")

local test = {}

---@param t testing.T
function test.basic(t)
	t:eq(ip.decode(0), "0.0.0.0")
	t:eq(ip.decode(1), "0.0.0.1")
	t:eq(ip.decode(255), "0.0.0.255")
	t:eq(ip.decode(256), "0.0.1.0")
	t:eq(ip.decode(4294967295), "255.255.255.255")
	t:eq(ip.decode(4294967296), "0.0.0.0")
	t:eq(ip.decode(4294967297), "0.0.0.1")

	t:eq(ip.encode("0.0.0.0"), 0)
	t:eq(ip.encode("0.0.0.1"), 1)
	t:eq(ip.encode("0.0.0.255"), 255)
	t:eq(ip.encode("0.0.1.0"), 256)
	t:eq(ip.encode("255.255.255.255"), 4294967295)
	t:eq(ip.encode("255.255.255.2555"), 0)
	t:eq(ip.encode("0.0.0.257"), 1)
end

return test
