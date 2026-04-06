local class = require("class")
local Box = require("ui.Box")

---@class ui.Layer
---@operator call: ui.Layer
---@field layout? ui.Layout
---@field composition_root? ui.composition.Node
---@field views ui.View[]
---@field ui_scale number
local Layer = class()

---@param view ui.View
---@param ui_scale number
local function attach_view(view, ui_scale)
	view.ui_scale = ui_scale
	view:refresh()
end

---@param view ui.View
---@param ui_scale number
local function refresh_view(view, ui_scale)
	view.ui_scale = ui_scale
	view:refresh()
end

function Layer:new()
	self.box = Box()
	self.views = {}
	self.ui_scale = 1
end

---@generic T: ui.View
---@param view T
---@return T
function Layer:add(view)
	---@cast view ui.View
	if view.transform == nil then
		error("Call View.new()")
	end

	if not view.box then
		view.box = self.box
	end

	table.insert(self.views, view)
	attach_view(view, self.ui_scale)
	return view
end

---@param views ui.View[]
function Layer:addArray(views)
	for _, v in ipairs(views) do
		self:add(v)
	end
end

---@param views ui.View[]
function Layer:setViews(views)
	self.views = {}
	self:addArray(views)
end

function Layer:load() end

---@param w number
---@param h number
---@param layout_scale number
---@param ui_scale? number
function Layer:updateDimensions(w, h, layout_scale, ui_scale)
	ui_scale = ui_scale or layout_scale or 1
	ui_scale = ui_scale > 0 and ui_scale or 1
	self.ui_scale = ui_scale

	if self.composition_root then
		local views = self.composition_root(0, 0, w / ui_scale, h / ui_scale, ui_scale)
		if #self.views == 0 then
			self:setViews(views)
		else
			self.views = views
		end
	end

	self.box:update(0, 0, w / ui_scale, h / ui_scale, ui_scale)

	if self.layout then
		self.layout:update(w, h, layout_scale)
	end

	for _, v in ipairs(self.views) do
		refresh_view(v, ui_scale)
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
