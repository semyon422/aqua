local Class = require("aqua.util.Class")
local Button = require("aqua.ui.Button")
local TextInputFrame = require("aqua.ui.TextInputFrame")
local CoordinateManager = require("aqua.graphics.CoordinateManager")

local Theme = Class:new()

Theme.cs = CoordinateManager:getCS(0, 0, 0, 0, "all")

Theme.Button = Button:new({
	x = 0,
	y = 0,
	w = 1,
	h = 1,
	rx = 0,
	ry = 0,
	backgroundColor = {255, 255, 255, 0},
	borderColor = {255, 255, 255, 0},
	textColor = {255, 255, 255, 255},
	lineStyle = "smooth",
	lineWidth = 0,
	cs = Theme.cs,
	limit = 1,
	textAlign = {x = "center", y = "center"},
	xpadding = 0,
	text = "",
	font = love.graphics.getFont(),
	enableStencil = false
})

Theme.TextInputFrame = TextInputFrame:new({
	x = 0,
	y = 0,
	w = 1,
	h = 1,
	rx = 0,
	ry = 0,
	backgroundColor = {255, 255, 255, 0},
	borderColor = {255, 255, 255, 0},
	textColor = {255, 255, 255, 255},
	lineStyle = "smooth",
	lineWidth = 0,
	cs = Theme.cs,
	limit = 1,
	textAlign = {x = "left", y = "center"},
	xpadding = 0,
	text = "",
	font = love.graphics.getFont(),
	enableStencil = false
})

return Theme
