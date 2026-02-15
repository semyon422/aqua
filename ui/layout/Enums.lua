local Enums = {}

---@enum ui.SizeMode
Enums.SizeMode = {
	Fixed = 1,
	Fit = 2,
	Auto = 3,
	Percent = 4,
}

---@enum ui.Arrange
Enums.Arrange = {
	Absolute = 1,
	FlowH = 2,
	FlowV = 3,
}

---@enum ui.Axis
Enums.Axis = {
	None = 0,
	X = 1,
	Y = 2,
	Both = 3,
}

---@enum ui.JustifyContent
Enums.JustifyContent = {
	Start = 1,
	End = 2,
	Center = 3,
	SpaceBetween = 4,
}

---@enum ui.AlignItems
Enums.AlignItems = {
	Start = 1,
	End = 2,
	Center = 3,
	Stretch = 4,
}

---@class ui.Pivot
---@field x number
---@field y number

Enums.Pivot = {
	TopLeft = {x = 0, y = 0},
	TopCenter = {x = 0.5, y = 0},
	TopRight = {x = 1, y = 0},
	CenterLeft = {x = 0, y = 0.5},
	Center = {x = 0.5, y = 0.5},
	CenterRight = {x = 1, y = 0.5},
	BottomLeft = {x = 0, y = 1},
	BottomCenter = {x = 0.5, y = 1},
	BottomRight = {x = 1, y = 1},
}

return Enums
