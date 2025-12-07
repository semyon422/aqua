# Pannya UI Framework
Pannya is a UI framework inspired by HTML/CSS, osu! framework, and Clay. You build UI like you do in HTML/CSS, because you are using Lua, you can partially mimic React/JSX style, by creating components as functions, no `useState()` though, as the state is stored inside Nodes themsevlves.

Features:
* Retained layout and nodes
* Flexbox-like layout system
* CSS-like styling
* Anchors, origins and absolute positioning if you hate flexbox.
* Input manager with bubbling mouse/keyboard events
* Probably a very good performance
* LuaLS annotations 

---

## Quick Start
```lua
local Engine = require("ui.nya.Engine")
local Node = require("ui.nya.Node")
local h = require("ui.luvx")

local window_style = {
	background_color = { 0.913, 0.925, 0.937, 1 },
    arrange = "flow_v",
    justify_items = "center",
    align_items = "center",
    child_gap = 4
}

local box_style = {
    width = 100,
    height = 100,
    background_color = { 1, 1, 1, 1 },
    border_radius = 10
}

local root =
    h(Node, window_style, {
        h(Node, box_style),
        h(Node, box_style),
        h(Node, box_style),
    })

local engine = Engine(root)

function love.update(dt)
	engine:updateTree(dt)
end

function love.draw()
	engine:drawTree()
end

function love.resize()
	engine:receive({ name = "resize" })
end
```

---

## Styling
Every node in the scene can have a style: it defines how the node looks visually. Pannya UI framework combines styling features into shaders.

### Features
* Content effects
    * Border radius
    * Gradients
    * Filters (Brightness, Contrast, Saturation, etc.)
* Backdrop effects
    * Multipass blur
    * Filters 
* Drop shadow
* Masks and clip
* Caching to a texture
---

## Layout
You have an option to use either a flexbox for everything, or position everything manually with absolute positioning and anchors with origins.

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
local Node = require("ui.nya.Node")

---@class Button : ui.Node
---@operator call: Button
local Button = Node + {}

local function nop() end

function Button:new()
    Node.new(self)
    self.text = "Default text"
    self.on_click = nop
    self.layout_box.x.size = 100
    self.layout_box.y.size = 50
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

    love.graphics.draw("fill", 0, 0, self.layout_box.x.size, self.layout_box.y.size)
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
