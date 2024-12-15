local DecoratorSocket = require("web.socket.DecoratorSocket")

---@class web.RangeSocket: web.DecoratorSocket
---@operator call: web.RangeSocket
local RangeSocket = DecoratorSocket + {}

---@param data string
---@param i integer?
---@param j integer?
---@return integer
---@return integer
local function normalize_bounds(data, i, j)
	i = i or 1
	j = j or #data

	if i < 0 then
		i = i + #data + 1
	end
	if j < 0 then
		j = j + #data + 1
	end

	i = math.max(i, 1)
	j = math.max(math.min(j, #data), i - 1)

	return i, j
end

---@param data string
---@param i integer?
---@param j integer?
---@return integer?
---@return "closed"|"timeout"?
---@return integer?
function RangeSocket:send(data, i, j)
	i, j = normalize_bounds(data, i, j)

	local bytes, err, _bytes = self.soc:send(data:sub(i, j))

	local n = (bytes or _bytes) + i - 1

	if bytes then
		return n
	end

	return nil, err, n
end

return RangeSocket
