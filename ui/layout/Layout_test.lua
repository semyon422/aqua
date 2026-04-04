local test = {}

local function make_transform()
	return {
		state = {0, 0, 0, 1, 1, 0, 0},
		setTransformation = function(self, x, y, r, sx, sy, ox, oy)
			self.state = {x, y, r, sx, sy, ox, oy}
			return self
		end,
		transformPoint = function(self, x, y)
			local state = self.state
			return state[1] + x * state[4], state[2] + y * state[5]
		end,
	}
end

_G.love = _G.love or {}
love.math = love.math or {}
love.math.newTransform = love.math.newTransform or make_transform

local Layout = require("ui.layout.Layout")

---@param t testing.T
function test.stack_alignment_and_scaling(t)
	local layout = Layout({
		target_height = 100,
		root = {
			w = "100%",
			h = "100%",
			children = {
				{
					id = "modal",
					w = 50,
					h = 20,
					align = {0.5, 0.5},
				},
			},
		},
	})

	layout:update(400, 200)
	local modal = layout:get("modal")

	t:eq(modal.x, 75)
	t:eq(modal.y, 40)
	t:eq(modal.width, 50)
	t:eq(modal.height, 20)
	t:assert(modal.transform ~= nil)
	local x1, y1 = modal.transform:transformPoint(0, 0)
	local x2, y2 = modal.transform:transformPoint(modal.width, modal.height)
	t:eq(x1, 150)
	t:eq(y1, 80)
	t:eq(x2, 250)
	t:eq(y2, 120)
end

---@param t testing.T
function test.row_and_col_fill_distribution(t)
	local layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			arrange = "col",
			children = {
				{
					id = "header",
					w = "100%",
					h = 50,
				},
				{
					id = "body",
					w = "100%",
					h = "*",
					arrange = "row",
					children = {
						{id = "sidebar", w = 100, h = "100%"},
						{id = "content", w = "*", h = "100%"},
						{id = "inspector", w = "*", h = "100%"},
					},
				},
			},
		},
	})

	layout:update(500, 300)

	local header = layout:get("header")
	local body = layout:get("body")
	local sidebar = layout:get("sidebar")
	local content = layout:get("content")
	local inspector = layout:get("inspector")

	t:eq(header.height, 50)
	t:eq(body.y, 50)
	t:eq(body.height, 250)
	t:eq(sidebar.width, 100)
	t:eq(content.width, 200)
	t:eq(inspector.width, 200)
	t:eq(content.x, 100)
	t:eq(inspector.x, 300)
end

---@param t testing.T
function test.fill_uses_remaining_space_on_main_axis(t)
	local layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			arrange = "row",
			children = {
				{id = "fixed", w = 100, h = "100%"},
				{id = "fill", w = "*", h = "100%"},
			},
		},
	})

	layout:update(1000, 200)

	t:eq(layout:get("fixed").width, 100)
	t:eq(layout:get("fill").width, 900)
	t:eq(layout:get("fill").x, 100)
end

---@param t testing.T
function test.multiple_fill_children_split_remaining_space_evenly(t)
	local row_layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			arrange = "row",
			children = {
				{id = "left", w = "*", h = "100%"},
				{id = "center", w = "*", h = "100%"},
				{id = "right", w = "*", h = "100%"},
			},
		},
	})

	row_layout:update(900, 120)

	t:eq(row_layout:get("left").width, 300)
	t:eq(row_layout:get("center").width, 300)
	t:eq(row_layout:get("right").width, 300)
	t:eq(row_layout:get("center").x, 300)
	t:eq(row_layout:get("right").x, 600)

	local col_layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			arrange = "col",
			children = {
				{id = "top", w = "100%", h = "*"},
				{id = "middle", w = "100%", h = "*"},
				{id = "bottom", w = "100%", h = "*"},
			},
		},
	})

	col_layout:update(120, 900)

	t:eq(col_layout:get("top").height, 300)
	t:eq(col_layout:get("middle").height, 300)
	t:eq(col_layout:get("bottom").height, 300)
	t:eq(col_layout:get("middle").y, 300)
	t:eq(col_layout:get("bottom").y, 600)
end

---@param t testing.T
function test.cross_axis_alignment_in_row_and_col(t)
	local layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			arrange = "row",
			children = {
				{
					id = "left",
					w = 80,
					h = 20,
					align = {0, 1},
				},
				{
					id = "right",
					w = 40,
					h = 50,
					align = {0, 0.5},
				},
			},
		},
	})

	layout:update(200, 100)
	t:eq(layout:get("left").y, 80)
	t:eq(layout:get("right").y, 25)

	layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			arrange = "col",
			children = {
				{
					id = "top",
					w = 40,
					h = 30,
					align = {1, 0},
				},
				{
					id = "bottom",
					w = 60,
					h = 20,
					align = {0.5, 0},
				},
			},
		},
	})

	layout:update(200, 100)
	t:eq(layout:get("top").x, 160)
	t:eq(layout:get("bottom").x, 70)
end

---@param t testing.T
function test.overflow_clamps_remaining_space(t)
	local layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			arrange = "row",
			children = {
				{id = "fixed", w = 200, h = "100%"},
				{id = "fill", w = "*", h = "100%"},
			},
		},
	})

	layout:update(100, 50)
	t:eq(layout:get("fixed").width, 200)
	t:eq(layout:get("fill").width, 0)
	t:eq(layout:get("fill").x, 200)
end

---@param t testing.T
function test.errors_for_invalid_specs_and_missing_ids(t)
	local err = t:has_error(function()
		Layout({
			root = {
				id = "dup",
				children = {
					{id = "dup"},
				},
			},
		})
	end)
	t:assert(err:match("Duplicate id") ~= nil, err)

	err = t:has_error(function()
		Layout({
			root = {
				w = "abc%",
				h = "100%",
			},
		})
	end)
	t:assert(err:match("Invalid w") ~= nil, err)

	local layout = Layout({
		root = {w = "100%", h = "100%"},
	})

	err = t:has_error(function()
		layout:get("missing")
	end)
	t:assert(err:match("Unknown id") ~= nil, err)
end

---@param t testing.T
function test.explicit_scale_and_integer_rounding(t)
	local layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			children = {
				{
					id = "box",
					w = 11,
					h = 7,
					align = {0.5, 0.5},
				},
			},
		},
	})

	layout:update(100, 50, 2)

	local box = layout:get("box")
	t:eq(box.width, 11)
	t:eq(box.height, 7)
	t:eq(box.x, 19.5)
	t:eq(box.y, 9)
	local x1, y1 = box.transform:transformPoint(0, 0)
	local x2, y2 = box.transform:transformPoint(box.width, box.height)
	t:eq(x1, 39)
	t:eq(y1, 18)
	t:eq(x2, 61)
	t:eq(y2, 32)
end

---@param t testing.T
function test.padding_offsets_and_shrinks_child_layout_space(t)
	local layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			padding = 10,
			children = {
				{
					id = "modal",
					w = 40,
					h = 20,
					align = {0.5, 0.5},
				},
			},
		},
	})

	layout:update(200, 100)

	local modal = layout:get("modal")
	t:eq(modal.x, 80)
	t:eq(modal.y, 40)
	t:eq(modal.width, 40)
	t:eq(modal.height, 20)
end

---@param t testing.T
function test.padding_affects_row_and_col_distribution(t)
	local row_layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			arrange = "row",
			padding = {10, 5, 30, 15},
			children = {
				{id = "fixed", w = 50, h = "100%"},
				{id = "fill", w = "*", h = "100%"},
			},
		},
	})

	row_layout:update(200, 80)

	t:eq(row_layout:get("fixed").x, 10)
	t:eq(row_layout:get("fixed").y, 5)
	t:eq(row_layout:get("fixed").height, 60)
	t:eq(row_layout:get("fill").x, 60)
	t:eq(row_layout:get("fill").width, 110)
	t:eq(row_layout:get("fill").height, 60)

	local col_layout = Layout({
		root = {
			w = "100%",
			h = "100%",
			arrange = "col",
			padding = {20, 10},
			children = {
				{id = "top", w = "100%", h = 30},
				{id = "bottom", w = "100%", h = "*"},
			},
		},
	})

	col_layout:update(200, 150)

	t:eq(col_layout:get("top").x, 20)
	t:eq(col_layout:get("top").y, 10)
	t:eq(col_layout:get("top").width, 160)
	t:eq(col_layout:get("bottom").y, 40)
	t:eq(col_layout:get("bottom").width, 160)
	t:eq(col_layout:get("bottom").height, 100)
end

---@param t testing.T
function test.errors_for_invalid_padding_specs(t)
	local err = t:has_error(function()
		Layout({
			root = {
				padding = "10",
			},
		})
	end)
	t:assert(err:match("Invalid padding") ~= nil, err)

	err = t:has_error(function()
		Layout({
			root = {
				padding = {10, 20, 30},
			},
		})
	end)
	t:assert(err:match("Invalid padding") ~= nil, err)
end

return test
