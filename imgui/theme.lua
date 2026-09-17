local theme = {}

local default_palette = {
	control = {1, 1, 1, 0.2},
	control_hover = {1, 1, 1, 0.3},
	control_active = {1, 1, 1, 0.4},
	boundless = {1, 1, 1, 0},
	boundless_hover = {1, 1, 1, 0.1},
	boundless_active = {1, 1, 1, 0.2},
	text = {1, 1, 1, 1},
	muted = {0.5, 0.5, 0.5, 1},
	accent = {1, 1, 1, 1},
	divider = {1, 1, 1, 1},
	scrollbar_track = {1, 1, 1, 0.12},
	scrollbar_thumb = {1, 1, 1, 0.65},
	scrollbar_thumb_hover = {1, 1, 1, 0.85},
}

local palette = default_palette
local palette_stack = {}

local function setColor(color)
	love.graphics.setColor(color)
end

---@param colors table
function theme.pushPalette(colors)
	palette_stack[#palette_stack + 1] = palette
	palette = setmetatable(colors, {__index = palette})
end

function theme.popPalette()
	palette = assert(table.remove(palette_stack), "imgui theme palette stack is empty")
end

function theme.setTextColor()
	setColor(palette.text)
end

function theme.setMutedColor()
	setColor(palette.muted)
end

function theme.setAccentColor()
	setColor(palette.accent)
end

function theme.setDividerColor()
	setColor(palette.divider)
end

---@param active boolean?
---@param hovered boolean?
function theme.setColor(active, hovered)
	setColor(active and palette.control_active or hovered and palette.control_hover or palette.control)
end

---@param active boolean?
---@param hovered boolean?
function theme.setColorBoundless(active, hovered)
	setColor(active and palette.boundless_active or hovered and palette.boundless_hover or palette.boundless)
end

---@param hovered boolean?
function theme.setScrollbarTrackColor(hovered)
	setColor(hovered and palette.control or palette.scrollbar_track)
end

---@param active boolean?
---@param hovered boolean?
function theme.setScrollbarThumbColor(active, hovered)
	setColor(active and palette.accent or hovered and palette.scrollbar_thumb_hover or palette.scrollbar_thumb)
end

theme.size = 0.75
theme.padding = 0.4
theme.indent = 0.1

---@param w number
---@param h number
---@param _h number?
---@return number
---@return number
---@return number
---@return number
---@return number
function theme._rectangle(w, h, _h)
	_h = _h or h
	local r = _h * theme.size / 2
	local x = _h * (1 - theme.size) / 2
	return x, x, w - x * 2, h - x * 2, r
end

---@param w number
---@param h number
function theme.rectangle(w, h)
	love.graphics.rectangle("fill", theme._rectangle(w, h))
end

---@param s number
---@param x number?
---@param y number?
function theme.circle(s, x, y)
	local r = s * theme.size / 3
	love.graphics.circle("fill", x or s / 2, y or s / 2, r, 64)
	love.graphics.circle("line", x or s / 2, y or s / 2, r, 64)
end

---@param w number
---@param h number?
---@param x number?
---@param y number?
function theme.fillrect(w, h, x, y)
	h = h or w
	local r = h * theme.size / 3
	local oy = h / 2 - r
	love.graphics.rectangle("fill", oy + (x or 0), oy + (y or 0), w - 2 * oy, h - 2 * oy, r, r, 64)
	love.graphics.rectangle("line", oy + (x or 0), oy + (y or 0), w - 2 * oy, h - 2 * oy, r, r, 64)
end

return theme
