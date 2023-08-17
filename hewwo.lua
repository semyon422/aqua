-- based on https://github.com/SayakaIsBaka/hewwo-node

local hewwo = {}

local kaomojis = {"(・`ω´・)", ";;w;;", "owo", "UwU", ">w<", "^w^"}

local gsubs = {
	{"r", "w"},
	{"l", "w"},
	{"R", "W"},
	{"L", "W"},
	{"ove", "uv"},
	{"([nN])([aeiou])", "%1y%2"},
	{"!+", function() return " " .. kaomojis[math.random(1, #kaomojis)] end},
}

---@param s string
---@return string
function hewwo.hewwoify(s)
	for i = 1, #gsubs do
		s = s:gsub(unpack(gsubs[i]))
	end
	return s
end

return hewwo
