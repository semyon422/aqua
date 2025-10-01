local class = require("class")
local LayoutEngine = require("ui.LayoutEngine")
local InputManager = require("ui.InputManager")
local Node = require("ui.Node")
local Axis = Node.Axis
local State = Node.State
require("table.clear")

---@class ui.Engine
---@operator call: ui.Engine
---@field mouse_target ui.Node?
---@field focus_requesters ui.Node[]
---@field layout_invalidation_requesters ui.Node[]
---@field rendering_context any[]
local Engine = class()

local RenderingOps = {
	Draw = 1,
	StencilStart = 2,
	StencilEnd = 3,
	BlurStart = 4,
	BlurEnd = 5
}

---@param root ui.Node
function Engine:new(root)
	self.root = root
	self.mouse_x = 0
	self.mouse_y = 0
	self.delta_time = 0
	self.mouse_target = nil
	self.focus_requesters = {}
	self.layout_invalidation_requesters = {}
	self.rendering_context = {}
	self.rebuild_rendering_context = false

	self.layout_engine = LayoutEngine(root)
	self.input_manager = InputManager()
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
		node.state = State.Ready
		self.rebuild_rendering_context = true
	end

	if (node.handles_mouse_input or node.handles_keyboard_input) and node.alpha * node.color[4] > 0 then
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
end

---@param node ui.Node
function Engine:buildRenderingContext(node)
	if node.draw then
		table.insert(self.rendering_context, RenderingOps.Draw)
		table.insert(self.rendering_context, node)
	end

	if node.stencil_mask then
		table.insert(self.rendering_context, RenderingOpsperations.StencilStart)
		table.insert(self.rendering_context, node)
	end

	for _, child in ipairs(node.children) do
		self:buildRenderingContext(child)
	end

	if node.stencil_mask then
		table.insert(self.rendering_context, RenderingOpsperations.StencilEnd)
	end
end

local handlers = {}

handlers[RenderingOps.Draw] = function(context, i)
	local node = context[i + 1]
	local c = node.color
	love.graphics.setColor(c[1], c[2], c[3], c[4] * node.alpha)
	love.graphics.push()
	love.graphics.applyTransform(node.transform)
	node:draw()
	love.graphics.pop()
	return 2
end

handlers[RenderingOps.StencilStart] = function(context, i) end
handlers[RenderingOps.StencilEnd] = function(context, i) end
handlers[RenderingOps.BlurStart] = function(context, i) end
handlers[RenderingOps.BlurEnd] = function(context, i) end

function Engine:drawTree()
	if self.rebuild_rendering_context then
		table.clear(self.rendering_context)
		self:buildRenderingContext(self.root)
		self.rebuild_rendering_context = false
	end

	local ctx = self.rendering_context
	local i, n = 1, #ctx
	while i <= n do
		i = i + handlers[ctx[i]](ctx, i)
	end
end

return Engine
