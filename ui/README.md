# Pannya UI Framework
Pannya is a UI framework inspired by Godot, osu! framework and Clay. It’s built around a scene graph: the UI is composed of nodes, where each node can have children and a parent.

Features:

* Retained layout and nodes
* Flexbox-like layout system
* Input manager with bubbling mouse/keyboard events
* Probably a very good performance
* LuaLS annotations

You can use retained nodes for layout and state, while still dropping into immediate mode just by doing everything inside the `draw` method. It's actually pretty useful, even I do this sometimes.

---

## Quick Start
```lua
local Node = require("ui.Node")
local Rectangle = require("ui.Rectangle")
local UIEngine = require("ui.Engine")

local root = Node({
    width = 1920,
    height = 1080,
})

root:add(Rectangle({
    anchor = Node.Pivot.Center,
    origin = Node.Pivot.Center,
    width = 100,
    height = 100,
    color = { 1, 0, 0, 1 }
}))

local engine = UIEngine(root)

engine:updateTree(dt)
engine:drawTree()
engine:receive(--[[ events go here ]]--)
```

---

## How It Works
A Pannya UI is just a tree of nodes. Each node stores state (position, size, input flags, etc.) and can be extended with custom logic. The engine takes care of the rest.

### Responsibilities
* Nodes: Containers with fields and overridable methods.
* Engine: Active manager that handles:
  * Layout updates
  * Input dispatch (mouse, keyboard, focus)
  * Update and draw loops

---

## What Not To Do
1. Don’t directly modify fields like `x`, `y`, `width`, or `height`.
   * Use setters, or call `invalidateAxis(Node.Axis.?)` after direct modification.
2. Don’t add nodes to a parent inside the `update()` method. Nodes themselves can add children to self anywhere they want.

---

## Events

```lua
Node:loadComplete()
Node:onKill()

Node:onHover()
Node:onHoverLost()

Node:onMouseDown(e)
Node:onMouseUp(e)
Node:onMouseClick(e)
Node:onScroll(e)
Node:onDragStart(e)
Node:onDrag(e)
Node:onDragEnd(e)
Node:onFocus(e)
Node:onFocusLost(e)
Node:onKeyDown(e)
Node:onKeyUp(e)
Node:onTextInput(e)
```

---

## More examples
### Inheritance
```lua
local Node = require("ui.Node")

---@class Button : ui.Node
---@operator call: Button
local Button = Node + {}

local function nop() end

---@param params table
function Button:new(params)
    self.text = "Default text"
    self.on_click = nop
    self.width = 100
    self.height = 50
    Node.new(self, params)
end

---@param e ui.MouseClickEvent
function Button:onMouseClick(e)
    if e.button == 1 then
        self.on_click()
    end
end

function Button:draw()
    if self.mouse_over then
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
    else
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
    end

    love.graphics.draw("fill", 0, 0, self.width, self.height)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        self.text, 
        self.width / 2, 
        self.height / 2, 
        0, 
        1, 
        1, 
        self.width / 2, 
        self.height / 2
    )
end

return Button
```

### Anchors and origins
```lua
local Node = require("ui.Node")
local Rectangle = require("ui.Rectangle")

local root = Node({
	width = love.graphics.getWidth(),
	height = love.graphics.getHeight()
})

local container = root:add(Node({
	width_mode = Node.SizeMode.Fit,
	height_mode = Node.SizeMode.Fit,
	anchor = Node.Pivot.Center,
	origin = Node.Pivot.Center,
}))

container:add(Rectangle({
	width = 100,
	height = 100,
	color = { 1, 0, 1, 1 }
}))

container:add(Rectangle({
	x = 100,
	width = 100,
	height = 100,
	color = { 0, 1, 1, 1 }
}))

container:add(Rectangle({
	x = 200,
	width = 100,
	height = 100,
	color = { 1, 1, 0, 1 }
}))
```

### Sugar
```lua
local Node = require("ui.Node")
local Rectangle = require("ui.Rectangle")

-- For the sugar in params
Node.TransformParams = require("ui.desugarizer")

-- Version with sugar:
local root = Node({
    size = { "fit", "fit" },
    arrange = "flow_h",
    padding = { 8, 8, 8, 8 }
})

-- And this is the version without it:
local root = Node({
    width_mode = Node.SizeMode.Fit,
    height_mode = Node.SizeMode.Fit,
    arrange = Node.Arrange.FlowH,
    padding_left = 8,
    padding_right = 8,
    padding_top = 8,
    padding_bottom = 8,
})
```

### Layout
```lua
local Node = require("ui.Node")
local Rectangle = require("ui.Rectangle")

Node.TransformParams = require("ui.desugarizer")

local root = Node({
    size = { 800, "fit" },
    arrange = "flow_h",
    padding = { 8, 8, 8, 8 },
    child_gap = 8
})

root:add(Rectangle({
    size = { 100, 100 },
}))

root:add(Rectangle({
    size = { "grow", "grow" },
}))

root:add(Rectangle({
    size = { "grow", "grow" },
}))

root:add(Rectangle({
    size = { "grow", "grow" },
}))

root:add(Rectangle({
    size = { 100, 100 },
}))
```

### If you are really lazy
```lua
local Node = require("ui.Node")

-- You can override every method when you pass params
-- Overriding new() method won't work
local a = Node({
    x = 100,
    y = 100
    load = function()
        local img = love.graphics.newImage("img.png")
        self.ps = love.graphics.newParticleSystem(img)
    end,
    update = function(dt)
        self.ps:update(dt)
    end,
    draw = function()
        self.ps:draw()
    end
})
```
