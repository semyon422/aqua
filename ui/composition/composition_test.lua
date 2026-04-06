local test = {}

local function make_transform()
	return {
		state = {0, 0, 0, 1, 1, 0, 0},
		setTransformation = function(self, x, y, r, sx, sy, ox, oy)
			self.state = {x, y, r, sx or 1, sy or 1, ox or 0, oy or 0}
			return self
		end,
		reset = function(self)
			self.state = {0, 0, 0, 1, 1, 0, 0}
			return self
		end,
		apply = function(self, other)
			local a = self.state
			local b = other.state or {0, 0, 0, 1, 1, 0, 0}
			self.state = {
				a[1] + b[1] * a[4],
				a[2] + b[2] * a[5],
				0,
				a[4] * b[4],
				a[5] * b[5],
				0,
				0,
			}
			return self
		end,
		transformPoint = function(self, x, y)
			local state = self.state
			return state[1] + x * state[4], state[2] + y * state[5]
		end,
		inverseTransformPoint = function(self, x, y)
			local state = self.state
			return (x - state[1]) / state[4], (y - state[2]) / state[5]
		end,
	}
end

_G.love = _G.love or {}
love.math = love.math or {}
love.math.newTransform = love.math.newTransform or make_transform
love.timer = love.timer or {}
love.timer.getTime = love.timer.getTime or function()
	return 0
end

local composition = require("ui.composition")
local View = require("ui.View")

local FixedView = View + {}

function FixedView:new(width, height)
	View.new(self)
	self.width = width
	self.height = height
end

---@param t testing.T
function test.stack_vertical_and_horizontal_layout(t)
	local top_a = FixedView(20, 10)
	local top_b = FixedView(30, 15)
	local bottom_a = FixedView(10, 20)
	local bottom_b = FixedView(10, 20)

	local root = composition.Stack({
		w = "100%",
		h = "100%",

		composition.Vertical({
			pivot = {0.5, 0.5},
			gap = 5,
			top_a,
			top_b,
		}),

		composition.Stack({
			w = "100%",
			h = 20,
			pivot = {0, 1},

			composition.Horizontal({
				w = "100%",
				h = "100%",
				gap = 4,
				align = {0.5, 0.5},
				bottom_a,
				bottom_b,
			}),
		}),
	})

	local views = root(0, 0, 100, 80, 1)
	t:eq(#views, 4)
	t:eq(views[1], top_a)
	t:eq(views[2], top_b)
	t:eq(views[3], bottom_a)
	t:eq(views[4], bottom_b)

	t:eq(top_a.box.x, 35)
	t:eq(top_a.box.y, 25)
	t:eq(top_a.box.width, 20)
	t:eq(top_a.box.height, 10)

	t:eq(top_b.box.x, 35)
	t:eq(top_b.box.y, 40)
	t:eq(top_b.box.width, 30)
	t:eq(top_b.box.height, 15)

	t:eq(bottom_a.box.x, 38)
	t:eq(bottom_a.box.y, 60)
	t:eq(bottom_b.box.x, 52)
	t:eq(bottom_b.box.y, 60)
end

---@param t testing.T
function test.fit_rejects_percent_sized_children(t)
	local view = FixedView(10, 10)
	view:setWidthPercent(1)

	local root = composition.Vertical({
		view,
	})

	local err = t:has_error(function()
		root(0, 0, 100, 80, 1)
	end)

	t:assert(err:match("width_percent") ~= nil, err)
end

---@param t testing.T
function test.constructor_rejects_view_reuse(t)
	local view = FixedView(10, 10)

	local err = t:has_error(function()
		composition.Horizontal({
			view,
			view,
		})
	end)

	t:assert(err:match("View reused") ~= nil, err)
end

---@param t testing.T
function test.padding_offsets_inner_layout_space(t)
	local child = FixedView(20, 10)

	local root = composition.Stack({
		w = "100%",
		h = "100%",
		padding = {10, 5, 30, 15},
		composition.Vertical({
			w = "100%",
			h = "100%",
			child,
		}),
	})

	local views = root(0, 0, 200, 100, 1)
	t:eq(#views, 1)
	t:eq(child.box.x, 10)
	t:eq(child.box.y, 5)
	t:eq(child.box.width, 20)
	t:eq(child.box.height, 10)
end

---@param t testing.T
function test.scalar_padding_offsets_inner_layout_space(t)
	local child = FixedView(20, 10)

	local root = composition.Stack({
		w = "100%",
		h = "100%",
		padding = 10,
		composition.Vertical({
			w = "100%",
			h = "100%",
			child,
		}),
	})

	root(0, 0, 200, 100, 1)
	t:eq(child.box.x, 10)
	t:eq(child.box.y, 10)
end

---@param t testing.T
function test.two_value_padding_offsets_inner_layout_space(t)
	local child = FixedView(20, 10)

	local root = composition.Stack({
		w = "100%",
		h = "100%",
		padding = {10, 5},
		composition.Vertical({
			w = "100%",
			h = "100%",
			child,
		}),
	})

	root(0, 0, 200, 100, 1)
	t:eq(child.box.x, 10)
	t:eq(child.box.y, 5)
end

---@param t testing.T
function test.horizontal_fill_uses_remaining_space(t)
	local left = FixedView(400, 50)
	local content = FixedView(10, 50)

	local root = composition.Horizontal({
		w = "100%",
		h = 100,
		left,
		composition.Stack({
			w = "*",
			h = "100%",
			content,
		}),
	})

	root(0, 0, 2023, 100, 1)

	t:eq(left.box.width, 400)
	t:eq(content.box.x, 400)
	t:eq(content.box.width, 1623)
end

---@param t testing.T
function test.vertical_fill_uses_remaining_space(t)
	local top = FixedView(50, 20)
	local content = FixedView(10, 50)

	local root = composition.Vertical({
		w = 100,
		h = "100%",
		top,
		composition.Stack({
			w = "100%",
			h = "*",
			content,
		}),
	})

	root(0, 0, 100, 80, 1)

	t:eq(top.box.height, 20)
	t:eq(content.box.y, 20)
	t:eq(content.box.height, 60)
end

---@param t testing.T
function test.horizontal_multiple_fill_children_split_remaining_space_equally(t)
	local left = FixedView(20, 10)
	local fill_a = FixedView(1, 10)
	local fill_b = FixedView(1, 10)

	local root = composition.Horizontal({
		w = 100,
		h = 10,
		left,
		composition.Stack({
			w = "*",
			h = "100%",
			fill_a,
		}),
		composition.Stack({
			w = "*",
			h = "100%",
			fill_b,
		}),
	})

	root(0, 0, 100, 10, 1)

	t:eq(fill_a.box.width, 40)
	t:eq(fill_b.box.width, 40)
	t:eq(fill_a.box.x, 20)
	t:eq(fill_b.box.x, 60)
end

---@param t testing.T
function test.vertical_multiple_fill_children_split_remaining_space_equally(t)
	local top = FixedView(10, 20)
	local fill_a = FixedView(10, 1)
	local fill_b = FixedView(10, 1)

	local root = composition.Vertical({
		w = 10,
		h = 100,
		top,
		composition.Stack({
			w = "100%",
			h = "*",
			fill_a,
		}),
		composition.Stack({
			w = "100%",
			h = "*",
			fill_b,
		}),
	})

	root(0, 0, 10, 100, 1)

	t:eq(fill_a.box.height, 40)
	t:eq(fill_b.box.height, 40)
	t:eq(fill_a.box.y, 20)
	t:eq(fill_b.box.y, 60)
end

---@param t testing.T
function test.horizontal_fill_measures_fixed_children_once(t)
	local fixed = composition.Stack({
		w = 40,
		h = 20,
		FixedView(1, 1),
	})
	local fill = composition.Stack({
		w = "*",
		h = 20,
		FixedView(1, 1),
	})

	local measure_count = 0
	local original_measure = fixed.measure

	function fixed:measure(...)
		measure_count = measure_count + 1
		return original_measure(self, ...)
	end

	local root = composition.Horizontal({
		w = 100,
		h = 20,
		fixed,
		fill,
	})

	root(0, 0, 100, 20, 1)
	t:eq(measure_count, 1)
end

---@param t testing.T
function test.vertical_fill_measures_fixed_children_once(t)
	local fixed = composition.Stack({
		w = 20,
		h = 30,
		FixedView(1, 1),
	})
	local fill = composition.Stack({
		w = 20,
		h = "*",
		FixedView(1, 1),
	})

	local measure_count = 0
	local original_measure = fixed.measure

	function fixed:measure(...)
		measure_count = measure_count + 1
		return original_measure(self, ...)
	end

	local root = composition.Vertical({
		w = 20,
		h = 100,
		fixed,
		fill,
	})

	root(0, 0, 20, 100, 1)
	t:eq(measure_count, 1)
end

---@param t testing.T
function test.vertical_main_align_centers_content_group(t)
	local first = FixedView(20, 10)
	local second = FixedView(20, 10)

	local root = composition.Vertical({
		w = 20,
		h = 50,
		align = {0.5, 0},
		first,
		second,
	})

	root(0, 0, 20, 50, 1)

	t:eq(first.box.y, 15)
	t:eq(second.box.y, 25)
end

---@param t testing.T
function test.horizontal_cross_align_centers_items(t)
	local short = FixedView(10, 10)
	local tall = FixedView(10, 20)

	local root = composition.Horizontal({
		w = 20,
		h = 40,
		align = {0, 0.5},
		short,
		tall,
	})

	root(0, 0, 20, 40, 1)

	t:eq(short.box.y, 15)
	t:eq(tall.box.y, 10)
end

---@param t testing.T
function test.fit_container_sizes_to_content(t)
	local first = FixedView(20, 10)
	local second = FixedView(30, 15)

	local root = composition.Vertical({
		gap = 5,
		first,
		second,
	})

	root(0, 0, 100, 100, 1)

	t:eq(root.box.width, 30)
	t:eq(root.box.height, 30)
end

---@param t testing.T
function test.single_child_does_not_add_gap(t)
	local child = FixedView(20, 10)

	local root = composition.Vertical({
		gap = 50,
		child,
	})

	root(0, 0, 100, 100, 1)
	t:eq(root.box.height, 10)
end

---@param t testing.T
function test.stack_pivot_positions_child_node(t)
	local child = FixedView(20, 10)

	local root = composition.Stack({
		w = 100,
		h = 80,
		composition.Stack({
			w = 20,
			h = 10,
			pivot = {0.5, 0.5},
			child,
		}),
	})

	root(0, 0, 100, 80, 1)
	t:eq(child.box.x, 40)
	t:eq(child.box.y, 35)
end

---@param t testing.T
function test.constructor_rejects_reused_nested_view(t)
	local shared = FixedView(10, 10)

	local err = t:has_error(function()
		composition.Horizontal({
			composition.Stack({
				shared,
			}),
			composition.Stack({
				shared,
			}),
		})
	end)

	t:assert(err:match("View reused") ~= nil, err)
end

---@param t testing.T
function test.constructor_rejects_reused_node(t)
	local shared = composition.Stack({
		w = 10,
		h = 10,
		FixedView(10, 10),
	})

	local err = t:has_error(function()
		composition.Horizontal({
			shared,
			shared,
		})
	end)

	t:assert(err:match("Composition node reused") ~= nil, err)
end

---@param t testing.T
function test.fit_rejects_height_percent_sized_children(t)
	local view = FixedView(10, 10)
	view:setHeightPercent(1)

	local root = composition.Horizontal({
		view,
	})

	local err = t:has_error(function()
		root(0, 0, 100, 80, 1)
	end)

	t:assert(err:match("height_percent") ~= nil, err)
end

---@param t testing.T
function test.root_fill_requires_explicit_available_size(t)
	local root = composition.Stack({
		w = "*",
		h = 10,
		FixedView(10, 10),
	})

	local err = t:has_error(function()
		root:measure(nil, 100)
	end)

	t:assert(err:match("w requires explicit parent size") ~= nil, err)
end

---@param t testing.T
function test.constructor_rejects_invalid_size_prop(t)
	local err = t:has_error(function()
		composition.Stack({
			w = "abc",
			h = 10,
			FixedView(10, 10),
		})
	end)

	t:assert(err:match("Invalid w") ~= nil, err)
end

---@param t testing.T
function test.constructor_rejects_invalid_gap_prop(t)
	local err = t:has_error(function()
		composition.Vertical({
			gap = "bad",
			FixedView(10, 10),
		})
	end)

	t:assert(err:match("Invalid gap") ~= nil, err)
end

---@param t testing.T
function test.constructor_rejects_invalid_padding_prop(t)
	local err = t:has_error(function()
		composition.Stack({
			padding = {10, "bad"},
			FixedView(10, 10),
		})
	end)

	t:assert(err:match("Invalid padding") ~= nil, err)
end

---@param t testing.T
function test.layout_scale_updates_box_transform_scale(t)
	local child = FixedView(20, 10)

	local root = composition.Stack({
		w = 50,
		h = 30,
		padding = 5,
		child,
	})

	root(3, 4, 50, 30, 2)

	local x1, y1 = child.box.transform:transformPoint(0, 0)
	local x2, y2 = child.box.transform:transformPoint(1, 1)
	t:eq(x1, 16)
	t:eq(y1, 18)
	t:eq(x2 - x1, 2)
	t:eq(y2 - y1, 2)
end

return test
