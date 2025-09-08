local class = require("class")
local table_util = require("table_util")

---@class im.Depth
---@operator call: im.Depth
---@field zindexes integer[]
---@field last_zindex integer
---@field next_over_id any?
---@field over_id any?
local Depth = class()

function Depth:new()
	self.zindexes = {}
	self.last_zindex = 0
	self:step()
end

function Depth:step()
	table_util.clear(self.zindexes)
	self.last_zindex = 0

	local new_over_id = self.next_over_id
	if self.over_id ~= new_over_id then
		self.exited_id = self.over_id
		self.entered_id = new_over_id
	else
		self.exited_id = nil
		self.entered_id = nil
	end

	self.over_id, self.next_over_id = self.next_over_id, nil
end

---@param id any
---@param over boolean
---@return boolean
function Depth:over(id, over)
	local zindexes = self.zindexes

	if not zindexes[id] then
		self.last_zindex = self.last_zindex + 1
		zindexes[id] = self.last_zindex
	end

	if over and zindexes[id] > (zindexes[self.next_over_id] or 0) then
		self.next_over_id = id
	end

	return rawequal(id, self.over_id)
end

return Depth
