local utf8 = require("utf8")
local just = require("just")
local theme = require("imgui.theme")

return function(id, text, index, w, h)
	local placeholder = ""
	if type(text) == "table" then
		text, placeholder = unpack(text)
	end
	if text == nil then
		text = ""
	end
	text = tostring(text)

	local font = love.graphics.getFont()
	local lh = font:getHeight() * font:getLineHeight()
	h = h or lh

	local changed, active, hovered = just.button(id, just.is_over(w, h))
	if changed then
		just.focus(id)
	end

	just.push()
	just.origin()
	just.row(true)

	theme.setColor(active, hovered)
	theme.rectangle(w, h)

	love.graphics.translate(h * theme.padding, (h - lh) / 2)
	love.graphics.setColor(1, 1, 1, 1)

	local clipw = w - h * theme.padding * 2
	just.clip(love.graphics.rectangle, "fill", 0, 0, clipw + 2, lh)

	local changed, left, right
	if just.focused_id == id then
		if just.keypressed("escape") then
			just.focus()
		end
		love.graphics.translate(math.min(clipw - font:getWidth(text), 0), 0)
		changed, text, index, left, right = just.textinput(text, index)
		just.text(left)
		local offset = just.text(right)
		just.indent(-offset)
		love.graphics.line(1, lh * 0.15, 1, lh * 0.85)
	else
		index = utf8.len(text) + 1
		just.text(text)
	end

	if not changed and text == "" then
		love.graphics.setColor(1, 1, 1, 0.5)
		just.text(placeholder)
	end

	just.clip()
	just.pop()
	just.next(w, h)

	return changed, text, index
end
