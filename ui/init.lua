local Drawable = require("ui.Drawable")

local sound_play_time = {}

---@param sound audio.Source
---@param limit number?
local function playSound(sound, limit)
	if not sound then
		print("no sound")
		return
	end

	limit = limit or 0.05

	local prev_time = sound_play_time[sound] or 0
	local current_time = love.timer.getTime()

	if current_time > prev_time + limit then
		sound:stop()
		sound_play_time[sound] = current_time
	end

	sound:play()
end

return {
	Drawable = Drawable,
	Padding = require("ui.Padding"),
	VBox = require("ui.VBox"),
	HBox = require("ui.HBox"),
	Stencil = require("ui.Stencil"),
	Image = require("ui.Image"),
	Label = require("ui.Label"),
	Rectangle = require("ui.Rectangle"),
	Pivot = Drawable.Pivot,
	SizeMode = Drawable.SizeMode,
	playSound = playSound
}
