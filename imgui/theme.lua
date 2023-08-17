local theme = {}

---@param active boolean?
---@param hovered boolean?
function theme.setColor(active, hovered)
	love.graphics.setColor(1, 1, 1, 0.2)
	if hovered then
		local alpha = active and 0.4 or 0.3
		love.graphics.setColor(1, 1, 1, alpha)
	end
end

---@param active boolean?
---@param hovered boolean?
function theme.setColorBoundless(active, hovered)
	love.graphics.setColor(1, 1, 1, 0)
	if hovered then
		local alpha = active and 0.2 or 0.1
		love.graphics.setColor(1, 1, 1, alpha)
	end
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

return theme
