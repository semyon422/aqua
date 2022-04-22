local Devices = {
	[0] = "unknown",
	"keyboard",
	"gamepad",
	"midi",
}

for k, v in pairs(Devices) do
	Devices[v] = k
end

return Devices
