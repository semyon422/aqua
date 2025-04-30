-- https://en.wikipedia.org/wiki/Merge_sort

local mergesort = {}

---@generic T
---@param a T[]
---@return T[]
local function copy_array(a)
	---@type T[]
	local b = {}
	for i = 1, #a do
		b[i] = a[i]
	end
	return b
end

---@generic T
---@param b T[]
---@param begin integer
---@param middle integer
---@param _end integer
---@param a T[]
local function merge(b, begin, middle, _end, a)
	local i = begin
	local j = middle

	for k = begin, _end do
		if i < middle and (j >= _end + 1 or a[i] <= a[j]) then
			b[k] = a[i]
			i = i + 1
		else
			b[k] = a[j]
			j = j + 1
		end
	end
end

---@generic T
---@param b T[]
---@param begin integer
---@param _end integer
---@param a T[]
local function split_merge(b, begin, _end, a)
	if _end - begin <= 0 then
		return
	end
	local middle = math.floor((_end + begin - 1) / 2) + 1
	split_merge(a, begin, middle - 1, b)
	split_merge(a, middle, _end, b)
	merge(b, begin, middle, _end, a)
end

---@generic T
---@param list T[]
function mergesort.sort(list)
	split_merge(list, 1, #list, copy_array(list))
end

-- test

local t = {8, 1, 7, 2, 6, 3, 5, 4}
mergesort.sort(t)
assert(table.concat(t) == "12345678", table.concat(t))

return mergesort
