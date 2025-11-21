local class = require("class")
local LayoutEngine = require("ui.layout.LayoutEngine")
local LayoutBox = require("ui.layout.LayoutBox")
local Renderer = require("ui.nya.Renderer")
local Node = require("ui.nya.Node")
local Inputs = require("ui.input.Inputs")
local TraversalContext = require("ui.input.TraversalContext")
local HoverEvent = require("ui.input.events.HoverEvent")
local HoverLostEvent = require("ui.input.events.HoverLostEvent")

local Axis = LayoutBox.Axis
local State = Node.State
require("table.clear")

---@class nya.Engine
---@operator call: nya.Engine
---@field layout_invalidation_requesters nya.Node[]
local Engine = class()

---@param root nya.Node
function Engine:new(root)
	self.root = root
	self.delta_time = 0
	self.layout_invalidation_requesters = {}
	self.rebuild_rendering_context = false

	self.layout_engine = LayoutEngine(root)
	self.renderer = Renderer()
	self.inputs = Inputs()
	self.traversal_context = TraversalContext()

	self.target_height = self.target_height or 768
end

function Engine:updateRootDimensions()
	local ww, wh = love.graphics.getDimensions()
	local s = self.target_height / wh
	local is = 1 / s
	self.root.layout_box:setDimensions(ww * s, self.target_height)
	self.root.transform:setScale(is, is)
	self.renderer:setViewportScale(is)
	self.renderer:build(self.root)
end

---@param node nya.Node
function Engine:updateNode(node)
	if node.is_disabled then
		return
	end

	if node.state == State.Ready then
		-- Do nothing
	elseif node.state == State.Loaded then
		node:loadComplete()
		node.layout_box:markDirty(Axis.Both)
		node.state = State.Ready
		self.rebuild_rendering_context = true
	elseif node.state == State.Killed then
		node:onKill()

		if node.parent then
			node.parent.layout_box:markDirty(Axis.Both)
		end

		self.rebuild_rendering_context = true
	elseif node.state == State.Created then
		node:load()
		node:loadComplete()
		node.layout_box:markDirty(Axis.Both)
		node.state = State.Ready
		self.rebuild_rendering_context = true
	end

	if node.handles_mouse_input or node.handles_keyboard_input then
		if node.handles_keyboard_input then
			table.insert(self.traversal_context.focus_requesters, node)
		end

		if not self.traversal_context.mouse_target and node.handles_mouse_input then
			local had_focus = node.mouse_over
			local imx, imy = node.transform:get():inverseTransformPoint(self.traversal_context.mouse_x,
				self.traversal_context.mouse_y)
			node.mouse_over = node:isMouseOver(self.traversal_context.mouse_x, self.traversal_context.mouse_y, imx, imy)

			if node.mouse_over then
				self.traversal_context.mouse_target = node
			end

			if not had_focus and node.mouse_over then
				local e = HoverEvent()
				e.target = node
				self.inputs:dispatchEvent(e)
			elseif had_focus and not node.mouse_over then
				local e = HoverLostEvent()
				e.target = node
				self.inputs:dispatchEvent(e)
			end
		else
			if node.mouse_over then
				node.mouse_over = false

				local e = HoverLostEvent()
				e.target = node
				self.inputs:dispatchEvent(e)
			end
		end
	end

	node:update(self.delta_time)

	for _, child in ipairs(node.children) do
		self:updateNode(child)
	end

	if not node.layout_box:isValid() then
		table.insert(self.layout_invalidation_requesters, node)
	end

	if node.transform.invalidated then
		-- This can be true only if the node.transform was changed with setters (animations)
		-- This will never be true HERE if layout was changed
		node:updateTreeTransform()
	end
end

---@param dt number
function Engine:updateTree(dt)
	self.traversal_context.mouse_x, self.traversal_context.mouse_y = love.mouse.getPosition()
	self.delta_time = dt
	self.traversal_context:reset()
	table.clear(self.layout_invalidation_requesters)

	self:updateNode(self.root)

	local updated_layout_roots = self.layout_engine:updateLayout(self.layout_invalidation_requesters)

	if updated_layout_roots then
		---@cast updated_layout_roots nya.Node
		for node, _ in pairs(updated_layout_roots) do
			node:updateTreeLayout()
			node:updateTreeTransform()
		end
	end

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
	if event.name == "resize" then
		self:updateRootDimensions()
	end

	self.inputs:receive(event, self.traversal_context)
end

return Engine
