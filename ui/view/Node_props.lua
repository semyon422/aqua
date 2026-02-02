local class = require("class")
local LayoutEnums = require("ui.layout.Enums")
local SizeMode = LayoutEnums.SizeMode
local Arrange = LayoutEnums.Arrange
local JustifyContent = LayoutEnums.JustifyContent
local AlignItems = LayoutEnums.AlignItems
local Pivot = LayoutEnums.Pivot

---@param str string
---@return ui.AlignItems
local function str_to_align(str)
	if str == "center" then
		return AlignItems.Center
	elseif str == "end" then
		return AlignItems.End
	elseif str == "stretch" then
		return AlignItems.Stretch
	end
	return AlignItems.Start
end

---@class view.Node.Getters
local Get = class()

---@class view.Node.Setters
local Set = class()

---@param node view.Node
---@param v "auto" | "fit" | number
function Set.width(node, v)
	local size = 0
	local mode = SizeMode.Auto
	if v == "auto" then
		mode = SizeMode.Auto
	elseif v == "fit" then
		mode = SizeMode.Fit
	elseif type(v) == "number" then
		size = v
		mode = SizeMode.Fixed
	end
	node.layout_box.x.preferred_size = size
	node.layout_box.x.mode = mode
end

---@param node view.Node
---@param v "auto" | "fit" | number
function Set.height(node, v)
	local size = 0
	local mode = SizeMode.Auto
	if v == "auto" then
		mode = SizeMode.Auto
	elseif v == "fit" then
		mode = SizeMode.Fit
	elseif type(v) == "number" then
		size = v
		mode = SizeMode.Fixed
	end
	node.layout_box.y.preferred_size = size
	node.layout_box.y.mode = mode
end

---@param node view.Node
---@param v number
function Set.min_width(node, v)
	node.layout_box.x.min_size = v
end

---@param node view.Node
---@param v number
function Set.max_width(node, v)
	node.layout_box.x.max_size = v
end

---@param node view.Node
---@param v number
function Set.min_height(node, v)
	node.layout_box.y.min_size = v
end

---@param node view.Node
---@param v number
function Set.max_height(node, v)
	node.layout_box.y.max_size = v
end


---@param node view.Node
---@param v ui.Color
function Set.color(node, v)
	node.color = v
end

---@param node view.Node
---@param v number
function Set.x(node, v)
	node.transform:setX(v)
end

---@param node view.Node
---@param v number
function Set.y(node, v)
	node.transform:setY(v)
end

---@param node view.Node
---@param v number
function Set.scale_x(node, v)
	node.transform:setScaleX(v)
end

---@param node view.Node
---@param v number
function Set.scale_y(node, v)
	node.transform:setScaleY(v)
end

---@param node view.Node
---@param v number
function Set.angle(node, v)
	node.transform:setAngle(v)
end

---@param node view.Node
---@param v string
function Set.arrange(node, v)
	local arrange = Arrange.Absolute

	if v == "absolute" then
		arrange = Arrange.Absolute
	elseif v == "flow_h" then
		arrange = Arrange.FlowH
	elseif v == "flow_v" then
		arrange = Arrange.FlowV
	end

	node.layout_box:setArrange(arrange)
end

---@param node view.Node
---@param v "start" | "center" | "end" | "stretch"
function Set.align_items(node, v)
	node.layout_box:setAlignItems(str_to_align(v))
end

---@param node view.Node
---@param v "start" | "center" | "end" | "stretch"
function Set.align_self(node, v)
	node.layout_box:setAlignSelf(str_to_align(v))
end

---@param node view.Node
---@param v "start" | "center" | "end" | "space_between"
function Set.justify_content(node, v)
	local jc = JustifyContent.Start
	if v == "center" then
		jc = JustifyContent.Center
	elseif v == "end" then
		jc = JustifyContent.End
	elseif v == "space_between" then
		jc = JustifyContent.SpaceBetween
	end
	node.layout_box:setJustifyContent(jc)
end

local props = {
	get = Get,
	set = Set
}

return props
