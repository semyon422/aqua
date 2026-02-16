local class = require("class")
local table_util = require("table_util")
local LayoutEngine = require("ui.layout.LayoutEngine")
local LayoutBox = require("ui.layout.LayoutBox")
local Renderer = require("ui.renderer")
local Node = require("ui.view.Node")
local Inputs = require("ui.input.Inputs")
local TraversalContext = require("ui.input.TraversalContext")
local HoverEvent = require("ui.input.events.HoverEvent")
local HoverLostEvent = require("ui.input.events.HoverLostEvent")

local Axis = LayoutBox.Axis
local State = Node.State

---@class ui.Engine
---@operator call: ui.Engine
---@field layout_invalidation_requesters view.Node[]
---@field removal_deferred view.Node[]
---@field current_scale number The current UI scale factor
local Engine = class()

---@param target_height number? Affects the scale of the entire UI. Pass nil to disable scaling
---@param height_scale number Multiplies target height
function Engine:new(target_height, height_scale)
	self.delta_time = 0
	self.layout_invalidation_requesters = {}
	self.removal_deferred = {}
	self.rebuild_rendering_context = false

	self.layout_engine = LayoutEngine()
	self.renderer = Renderer()
	self.inputs = Inputs()
	self.traversal_context = TraversalContext()

	self.target_height = target_height
	self.height_scale = height_scale or 1
end

---@param root view.Node
function Engine:setRoot(root)
	self.root = root
	self:updateRootDimensions()
	root:mount(self.inputs)
end

---@param target_height number? Pass nil to disable scaling
function Engine:setTargetHeight(target_height)
	self.target_height = target_height
	self:updateRootDimensions()
end

---@param height_scale number
function Engine:setHeightScale(height_scale)
	self.height_scale = height_scale
	self:updateRootDimensions()
end

function Engine:updateRootDimensions()
	local ww, wh = love.graphics.getDimensions()
	local target_height = wh

	if self.target_height then
		target_height = self.target_height * (self.height_scale or 1)
	end

	local s = target_height / wh
	local is = 1 / s

	self.current_scale = s

	self.root.layout_box:setDimensions(ww * s, target_height)
	self.root.transform:setScale(is, is)
	self.renderer:setViewportScale(is)
end

---@param node view.Node
function Engine:updateNode(node)
	if node.is_disabled then
		return
	end

	local state = node.state

	if state == State.Ready then
		-- Do nothing
	elseif state == State.Loaded then
		node:loadComplete()
		node.layout_box:markDirty(Axis.Both)
		node.state = State.Ready
		self.rebuild_rendering_context = true
	elseif state == State.Killed then
		table.insert(self.removal_deferred, node)
		return
	elseif state == State.AwaitsMount then
		error("Encountered a non-mounted node. Make sure you used Engine:setRoot() and Node:add() to add nodes to the tree. Do not insert nodes directly into node.children")
	end

	if node.handles_mouse_input or node.handles_keyboard_input then
		if node.handles_keyboard_input then
			table.insert(self.traversal_context.focus_requesters, node)
		end

		if not self.traversal_context.mouse_target and node.handles_mouse_input then
			local had_focus = node.mouse_over
			local imx, imy = node.transform:get():inverseTransformPoint(
				self.traversal_context.mouse_x,
				self.traversal_context.mouse_y
			)
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
	table_util.clear(self.layout_invalidation_requesters)

	self:updateNode(self.root)

	if #self.removal_deferred ~= 0 then
		for _, v in ipairs(self.removal_deferred) do
			local parent = v.parent

			self:finalizeRemoval(v)

			if parent then
				parent:remove(v)
				parent.layout_box:markDirty(Axis.Both)
				self.rebuild_rendering_context = true
			end
		end
		self.removal_deferred = {}
	end

	local updated_layout_roots = self.layout_engine:updateLayout(self.layout_invalidation_requesters)

	if updated_layout_roots then
		for node, _ in pairs(updated_layout_roots) do
			---@cast node -ui.LayoutEngine.Node, +view.Node
			node:updateTreeLayout()
			node:updateTreeTransform()
		end
	end

	if self.rebuild_rendering_context then
		self.renderer:build(self.root)
		self.rebuild_rendering_context = false
	end
end

---@param node view.Node
function Engine:finalizeRemoval(node)
	for _, child in ipairs(node.children) do
		self:finalizeRemoval(child)
		child.state = State.Killed
	end
	node:destroy()
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
