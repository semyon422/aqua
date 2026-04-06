local class = require("class")

---@class ui.Layer
---@operator call: ui.Layer
---@field composition_root? ui.composition.Node
---@field views ui.View[]
local Layer = class()

---@param view ui.View
local function attach_view(view)
	if view.transform == nil then
		error("Call View.new()")
	end
	if not view.box then
		error("ui.Layer requires composition-assigned view.box")
	end
end

---@param views ui.View[]
local function set_views(self, views)
	self.views = {}
	for _, view in ipairs(views) do
		attach_view(view)
		table.insert(self.views, view)
	end
end

function Layer:new()
	self.views = {}
end

function Layer:load() end

---@param w number
---@param h number
---@param layout_scale number
function Layer:updateDimensions(w, h, layout_scale)
	layout_scale = layout_scale > 0 and layout_scale or 1

	assert(self.composition_root, "ui.Layer requires composition_root")
	local views = self.composition_root(0, 0, w / layout_scale, h / layout_scale, layout_scale)
	set_views(self, views)

	for _, v in ipairs(self.views) do
		v.ui_scale = layout_scale
		v:applyLayout()
	end
end

---@param dt number
function Layer:update(dt)
	for _, v in ipairs(self.views) do
		v:update(dt)
	end
end

---@param inputs ui.Inputs
function Layer:acceptInputs(inputs)
	for i = #self.views, 1, -1 do
		local v = self.views[i]
		v:acceptInputs(inputs)
	end
end

function Layer:draw()
	for _, v in ipairs(self.views) do
		if v.visible then
			love.graphics.push("all")
			love.graphics.applyTransform(v.transform)
			v:draw()
			love.graphics.pop()
		end
	end
end

---@param event table
function Layer:receive(event) end

return Layer
