local ffi = require("ffi")

---@param byte integer
---@return boolean
local function isContinuation(byte)
	return byte >= 0x80 and byte <= 0xBF
end

---@param s string
---@param index integer
---@return integer?
local function getSequenceLength(s, index)
	local first = s:byte(index)
	if first <= 0x7F then
		return 1
	end
	local second = s:byte(index + 1)
	if first >= 0xC2 and first <= 0xDF then
		return second and isContinuation(second) and 2 or nil
	end
	local third = s:byte(index + 2)
	if first == 0xE0 then
		return second and second >= 0xA0 and second <= 0xBF and third and isContinuation(third) and 3 or nil
	elseif first >= 0xE1 and first <= 0xEC or first >= 0xEE and first <= 0xEF then
		return second and isContinuation(second) and third and isContinuation(third) and 3 or nil
	elseif first == 0xED then
		return second and second >= 0x80 and second <= 0x9F and third and isContinuation(third) and 3 or nil
	end
	local fourth = s:byte(index + 3)
	if first == 0xF0 then
		return second and second >= 0x90 and second <= 0xBF and third and isContinuation(third)
			and fourth and isContinuation(fourth) and 4 or nil
	elseif first >= 0xF1 and first <= 0xF3 then
		return second and isContinuation(second) and third and isContinuation(third)
			and fourth and isContinuation(fourth) and 4 or nil
	elseif first == 0xF4 then
		return second and second >= 0x80 and second <= 0x8F and third and isContinuation(third)
			and fourth and isContinuation(fourth) and 4 or nil
	end
end

---@param s string
---@param c string?
local function validate(s, c)
	c = c or "?"
	local size = #s
	local buffer = ffi.new("char[?]", size)

	---@type {[integer]: integer}
	local ptr = ffi.cast("char*", buffer)
	ffi.copy(buffer, s, size)

	local index = 1
	while index <= size do
		local sequence_length = getSequenceLength(s, index)
		if sequence_length then
			index = index + sequence_length
		else
			ptr[index - 1] = c:byte()
			index = index + 1
		end
	end

	return ffi.string(buffer, size)
end

return validate
