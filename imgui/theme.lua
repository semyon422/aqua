local theme = {}

function theme.setColor(active, hovered)
	love.graphics.setColor(1, 1, 1, 0.2)
	if hovered then
		local alpha = active and 0.4 or 0.3
		love.graphics.setColor(1, 1, 1, alpha)
	end
end

function theme.setColorBoundless(active, hovered)
	love.graphics.setColor(1, 1, 1, 0)
	if hovered then
		local alpha = active and 0.2 or 0.1
		love.graphics.setColor(1, 1, 1, alpha)
	end
end

theme.size = 0.75
theme.padding = 0.4

function theme._rectangle(w, h)
	local r = h * theme.size / 2
	local x = h * (1 - theme.size) / 2
	return x, x, w - x * 2, h - x * 2, r
end

function theme.rectangle(w, h)
	love.graphics.rectangle("fill", theme._rectangle(w, h))
end

function theme.circle(s)
	local r = s * theme.size / 3
	love.graphics.circle("fill", s / 2, s / 2, r, 64)
	love.graphics.circle("line", s / 2, s / 2, r, 64)
end

return theme
