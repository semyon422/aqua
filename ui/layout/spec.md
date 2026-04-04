# UI Layout System Specification

## Overview

This layout system is a **static, explicit UI layout engine** designed for simplicity and predictability.

It deliberately avoids complexity:

* No dirty flags
* No incremental updates
* No intrinsic/content-based sizing
* No measurement passes
* No constraint solving

Each update fully recomputes the layout tree from scratch.

The system is suitable for game UIs and similar environments where layout is known ahead of time and performance requirements are moderate.

---

## Core Principles

1. **Stateless layout computation**

   * Layout is recomputed entirely on each `update`.

2. **Explicit sizing only**

   * No automatic sizing based on content.

3. **Deterministic behavior**

   * Layout depends only on:

     * layout tree
     * viewport size
     * optional scaling configuration

4. **Strict ownership**

   * Layout owns all `Box` instances.
   * Consumers (e.g. Views) must treat boxes as **read-only**.

---

## Data Model

### Box

Represents a resolved layout result.

```lua
---@class ui.Box
---@field x number
---@field y number
---@field width number
---@field height number
---@field transform love.Transform
```

Notes:

* `x`, `y`, `width`, and `height` are stored in **logical root space**.
* `transform` is updated in-place every layout pass and maps logical box space to screen space.
* Box instances are persistent and reused across updates.

---

### LayoutNode

Defines layout behavior.

```lua
---@class ui.LayoutNode
---@field id? string
---@field w? number|string        -- number, "*", or "n%"
---@field h? number|string
---@field align? [number, number] -- 0..1 range, default {0, 0}
---@field arrange? "stack"|"row"|"col" -- default "stack"
---@field children? ui.LayoutNode[]
```

---

### Layout

```lua
---@class ui.Layout
---@field boxes table<string, ui.Box>
---@field root ui.LayoutNode
---@field target_height number?
```

---

## API

### Constructor

```lua
Layout(config)
```

```lua
---@class ui.Layout.Config
---@field root ui.LayoutNode
---@field target_height? number
```

* `root` is required
* `target_height` enables uniform scaling

---

### Update

```lua
layout:update(viewport_width, viewport_height, layout_scale?)
```

* Recomputes entire layout tree
* Updates all boxes in-place
* `layout_scale` is optional and controls the root logical viewport size plus each box transform
* If omitted, `target_height` still provides `layout_scale = viewport_height / target_height`

---

### Access

```lua
layout:get(id) -> ui.Box
```

* Returns box by id
* Throws if id does not exist

---

## Sizing Rules

Each node supports:

| Value    | Meaning                   |
| -------- | ------------------------- |
| `number` | Fixed size in logical units |
| `"n%"`   | Percentage of parent size |
| `"*"`    | Fill remaining space      |
| `nil`    | Equivalent to `"*"`       |

---

### Fixed

```lua
w = 200
```

Resolves directly to logical units.

---

### Percent

```lua
w = "50%"
```

Resolves as:

```
w = parent.width * 0.5
```

Percent is always based on **full parent size**, not remaining space.

---

### Fill (`"*"`)

Fill consumes remaining space after fixed and percent sizes are resolved.

Behavior depends on layout mode:

#### In `row` / `col`

* Remaining space is divided evenly among fill children along the **main axis**
* On the cross axis, fill = full parent size

#### In `stack`

* Fill = full parent size on that axis

---

## Arrangement Modes

### `stack` (default)

* Children are independently positioned inside parent
* No sequencing

---

### `row`

* Children laid out left → right
* Main axis: width
* Cross axis: height

Steps:

1. Resolve fixed and percent widths
2. Compute remaining width
3. Distribute to `"*"` children
4. Place children sequentially along X

---

### `col`

* Children laid out top → bottom
* Main axis: height
* Cross axis: width

Steps:

1. Resolve fixed and percent heights
2. Compute remaining height
3. Distribute to `"*"` children
4. Place children sequentially along Y

---

## Alignment

Each node has:

```lua
align = {ax, ay}
```

* Range: `[0, 1]`
* Default: `{0, 0}` (top-left)

---

### Semantics

#### `stack`

Alignment affects both axes:

```
x = parent.x + (parent.width  - node.width)  * ax
y = parent.y + (parent.height - node.height) * ay
```

---

#### `row`

* X is determined by flow
* Y uses alignment:

```
y = parent.y + (parent.height - node.height) * ay
```

---

#### `col`

* Y is determined by flow
* X uses alignment:

```
x = parent.x + (parent.width - node.width) * ax
```

---

## Root Scaling

If `target_height` is set and `layout_scale` is not provided:

```
scale = viewport_height / target_height
```

The root logical viewport becomes:

```
logical_width = viewport_width / scale
logical_height = viewport_height / scale
```

* Fixed sizes (`number`) stay in logical units
* Percent values resolve from the parent box in logical space
* `box.transform` applies the uniform logical-to-screen scale

---

## Layout Algorithm

For each node:

### 1. Resolve Size

* Compute `width`, `height` using sizing rules

---

### 2. Resolve Position

* Based on:

  * arrangement mode
  * alignment

---

### 3. Update Box

Set:

```lua
box.x
box.y
box.width
box.height
```

Update:

```lua
box.transform:setTransformation(...)
```

---

### 4. Layout Children

Depends on `arrange`:

* `stack` → pass full parent box
* `row` / `col` → apply flow algorithm

---

## Error Handling

The system should fail early for invalid input.

### Must error:

* Invalid size string
* Malformed percent (e.g. `"abc%"`)
* Duplicate `id`
* Missing box access (`get(id)`)
* Invalid node structure

### Runtime handling:

* Negative remaining space → clamp to `0`
* Overflow is allowed (children may exceed parent bounds)

---

## ID Rules

* Each node may define an `id`
* IDs must be globally unique
* Only nodes with IDs are accessible via `layout:get`

---

## Ownership Rules

* Layout exclusively owns all `Box` instances
* Boxes are updated internally each frame
* External code (e.g. Views):

  * may read box properties
  * must not mutate them

Violating this breaks layout consistency.

---

## Example

```lua
local layout = Layout({
	target_height = 1080,

	root = {
		w = "100%",
		h = "100%",
		arrange = "stack",
		children = {
			{
				id = "modal",
				w = 1000,
				h = 800,
				align = {0.5, 0.5},
				arrange = "col",
				children = {
					{
						id = "top_bar",
						w = "100%",
						h = 50,
					},
					{
						id = "container",
						w = "100%",
						h = "*",
						arrange = "row",
						children = {
							{
								id = "tabs",
								w = 170,
								h = "100%",
							},
							{
								id = "content",
								w = "*",
								h = "100%",
							}
						}
					}
				}
			}
		}
	}
})

layout:update(love.graphics.getWidth(), love.graphics.getHeight())

local modal = layout:get("modal")
```

---

## Non-Goals

This system does **not** support:

* Intrinsic sizing (text, content measurement)
* Constraints (min/max size)
* Flexbox-like distribution rules
* Dirty propagation / partial updates
* Layout invalidation tracking

---

## Future Extensions (Optional)

These are intentionally excluded from core design:

* `gap` for row/col spacing
* `padding` for containers
* min/max constraints
* clipping / scroll regions

They can be added later without changing core architecture.

---

## Summary

This layout system prioritizes:

* clarity
* predictability
* minimal implementation complexity

It is designed to remain small, explicit, and easy to reason about.
