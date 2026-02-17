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
	FlexRow = 2,
	FlexCol = 3,
	Grid = 4,
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

return Enums
