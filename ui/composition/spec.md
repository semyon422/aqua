# View Composition

## Goal

Provide a small composition system for `ui.View` trees.

Supported helpers:

* `Stack(...)`
* `Vertical(...)`
* `Horizontal(...)`

Each helper:

1. Accepts views and nested composition nodes.
2. Resolves positions and sizes.
3. Assigns persistent `ui.Box` instances to leaf views.
4. Returns a flat `ui.View[]` in draw order.

## User Experience

```lua
local compose = require("ui.composition")

local root = compose.Stack({
	compose.Vertical({
		w = "100%",
		h = "100%",
		padding = {100, 60, 100, 60},
		gap = 20,

		compose.Stack({
			w = "100%",
			h = 120,
			title_view,
		}),

		compose.Horizontal({
			w = "100%",
			h = "*",
			gap = 20,

			compose.Stack({
				w = 400,
				h = "100%",
				tabs_view,
			}),

			compose.Stack({
				w = "*",
				h = "100%",
				background_view,
				compose.Stack({
					w = "100%",
					h = "100%",
					padding = 5,
					content_view,
				}),
			}),
		}),
	}),
})

layer.composition_root = root
```

`ui.Layer:updateDimensions()` reruns `composition_root` automatically when present.

## Data Model

### Node

```lua
---@class ui.composition.Node
---@field kind "stack"|"vertical"|"horizontal"
---@field box ui.Box
---@field children (ui.View|ui.composition.Node)[]
---@field props table
```

### View Ownership

Composition owns the assigned boxes.

Rules:

* each composition node keeps one persistent `ui.Box`
* each leaf view keeps one persistent `ui.Box`
* boxes are updated in place on relayout
* one `ui.View` instance cannot appear twice in the same tree

## Sizing Rules

Supported size values:

* `number`: fixed logical size
* `"n%"`: percentage of parent inner size
* `"*"`: fill remaining main-axis space in `Vertical` / `Horizontal`, or fill parent size in `Stack`
* `nil`: same as `"*"` for node sizes

### Stack

Children are overlaid.

For a child node:

* `pivot` controls placement inside the parent inner box

For a leaf view:

* the parent inner box is assigned directly

### Vertical

Main axis: height

* fixed-height children consume fixed height
* `"*"` children split the remaining height after fixed children and gaps
* `"100%"` means full parent inner height, not remaining height

### Horizontal

Main axis: width

* fixed-width children consume fixed width
* `"*"` children split the remaining width after fixed children and gaps
* `"100%"` means full parent inner width, not remaining width

### Important Distinction

Use `"*"` when a child should take leftover space after earlier siblings.

Do not use `"100%"` for that case.

Example:

```lua
Vertical({
	w = "100%",
	h = "100%",
	header,
	Horizontal({
		w = "100%",
		h = "*",
		content,
	}),
})
```

If that row used `h = "100%"`, it would ask for the full parent height and overflow below the header.

## Padding

Supported forms:

* `padding = 10`
* `padding = {x, y}`
* `padding = {left, top, right, bottom}`

Padding shrinks the inner box used for:

* child measurement
* child placement
* percent sizing
* fill sizing

For fitted nodes, padding contributes to the final outer size.

## Fit Containers

`Vertical` and `Horizontal` can fit their own size when an axis is not explicitly set.

Rules:

### Vertical fit

If `w` is omitted:

* width = max child widths + horizontal padding

If `h` is omitted:

* height = sum child heights + gaps + vertical padding

### Horizontal fit

If `w` is omitted:

* width = sum child widths + gaps + horizontal padding

If `h` is omitted:

* height = max child heights + vertical padding

## Invalid Cases

Fit only works when sizing dependencies are acyclic.

These cases must fail loudly:

* `width_percent` on a child inside a fit-width container
* `height_percent` on a child inside a fit-height container
* `"100%"` on an axis whose parent is trying to fit from children
* `"*"` on an axis whose parent is trying to fit from children
* duplicate view instances in one tree

Examples:

```lua
Vertical({
	ui:Button():setWidthPercent(1),
})
```

```lua
Horizontal({
	composition.Stack({
		w = "*",
		...
	}),
})
```

inside a fit-width parent

## View Refresh

Composition only updates boxes. Views still need `view:applyLayout()`.

That is handled automatically by `ui.Layer` when `composition_root` is set.

`ui.Layer` is composition-driven. Views should enter a layer through `composition_root`, not through imperative layer insertion.

`applyLayout()` is intended for attach and layout changes, not for normal animation or scrolling.
Per-frame motion should update transforms or scroll state without rebuilding child layout.

## Draw And Input Order

Flattening uses depth-first declaration order.

Consequences:

* later views draw on top
* later views receive input first
* focus order follows the flat array order

## Practical Scope

The current system is intentionally simple:

* full relayout is allowed
* no incremental invalidation
* no constraint solving
* no intrinsic text measurement in composition itself
* no duplicate view ownership

If layout inputs change, rerun the whole composition tree.

## Conclusion

This system is intended to stay small and explicit.

The important rules are:

* boxes are owned by composition
* `"*"` means remaining main-axis space
* `"100%"` means full parent inner size
* fit containers only accept children with non-cyclic size dependencies
* invalid cases should crash loudly
