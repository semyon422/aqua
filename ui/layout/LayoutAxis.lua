local class = require("class")
local Enums = require("ui.layout.Enums")
local SizeMode = Enums.SizeMode

---@class ui.LayoutAxis
---@field pos number Managed by LayoutEngine, don't change manually
---@field size number Managed by LayoutEngine, don't change manually
---@field preferred_size number
---@field min_size number
---@field max_size number
---@field flex_grow number
---@field mode ui.SizeMode
---@field padding_start number
---@field padding_end number
local LayoutAxis = class()

function LayoutAxis:new()
	self.pos = 0
	self.size = 0
	self.preferred_size = 0
	self.min_size = 0
	self.max_size = math.huge
	self.mode = SizeMode.Auto
	self.padding_start = 0
	self.padding_end = 0
end

---@param size number
function LayoutAxis:setSize(size)
	self.size = size
	self.preferred_size = size
	self.mode = SizeMode.Fixed
end

---@param min number
---@param max number
function LayoutAxis:setLimits(min, max)
	self.min_size = min
	self.max_size = max
end

return LayoutAxis
