local class = require("class")
local LayoutEngine = require("ui.LayoutEngine")
local InputManager = require("ui.InputManager")
local Renderer = require("ui.Renderer")
local Node = require("ui.Node")
local Axis = Node.Axis
local State = Node.State
require("table.clear")

---@class ui.Engine
---@operator call: ui.Engine
---@field mouse_target ui.Node?
---@field focus_requesters ui.Node[]
---@field layout_invalidation_requesters ui.Node[]
local Engine = class()

---@param root ui.Node
function Engine:new(root)
	self.root = root
	self.mouse_x = 0
	self.mouse_y = 0
	self.delta_time = 0
	self.mouse_target = nil
	self.focus_requesters = {}
	self.layout_invalidation_requesters = {}
	self.rebuild_rendering_context = false

	self.layout_engine = LayoutEngine(root)
	self.input_manager = InputManager()
	self.renderer = Renderer()

	self.target_height = self.target_height or 768
end

function Engine:updateRootDimensions()
	local ww, wh = love.graphics.getDimensions()
	local s = self.target_height / wh
	local is = 1 / s
	self.root:setDimensions(ww * s, self.target_height)
	self.root:setScale(is, is)
	self.renderer:setViewportScale(is)
end

---@param node ui.Node
function Engine:updateNode(node)
	if node.is_disabled then
		return
	end

	if node.state == State.Ready then
		-- Do nothing
	elseif node.state == State.Loaded then
		node:loadComplete()
		node:invalidateAxis(Axis.Both)
		node.state = State.Ready
		self.rebuild_rendering_context = true
	elseif node.state == State.Killed then
		node:onKill()

		if node.parent then
			node.parent:invalidateAxis(Axis.Both)
		end

		self.rebuild_rendering_context = true
	elseif node.state == State.Created then
		node:load()
		node:loadComplete()
		node:invalidateAxis(Axis.Both)
		node.state = State.Ready
		self.rebuild_rendering_context = true
	end

	if node.handles_mouse_input or node.handles_keyboard_input then
		if node.handles_keyboard_input then
			table.insert(self.focus_requesters, node)
		end

		if not self.mouse_target and node.handles_mouse_input then
			local had_focus = node.mouse_over
			local imx, imy = node.transform:inverseTransformPoint(self.mouse_x, self.mouse_y)
			node.mouse_over = node:isMouseOver(self.mouse_x, self.mouse_y, imx, imy)

			if node.mouse_over then
				self.mouse_target = node
			end

			-- TODO: dispatch an event
			if not had_focus and node.mouse_over then
				node:onHover()
			elseif had_focus and not node.mouse_over then
				node:onHoverLost()
			end
		else
			if node.mouse_over then
				node:onHoverLost()
				node.mouse_over = false
			end
		end
	end

	node:update(self.delta_time)

	for _, child in ipairs(node.children) do
		self:updateNode(child)
	end

	if node.invalidate_axis ~= Axis.None then
		table.insert(self.layout_invalidation_requesters, node)
	end
end

---@param dt number
function Engine:updateTree(dt)
	self.mouse_x, self.mouse_y = love.mouse.getPosition()
	self.delta_time = dt
	self.mouse_target = nil
	table.clear(self.focus_requesters)
	table.clear(self.layout_invalidation_requesters)

	self:updateNode(self.root)
	self.layout_engine:updateLayout(self.layout_invalidation_requesters)

	if self.rebuild_rendering_context then
		self.renderer:build(self.root)
		self.rebuild_rendering_context = false
	end
end

function Engine:drawTree()
	self.renderer:draw()
end

---@param event { name: string, [number]: any }
function Engine:receive(event)
	if event.name ~= "resize" then
		self:updateRootDimensions()
	end
end

return Engine
