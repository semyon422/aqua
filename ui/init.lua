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
	playSound = playSound,
}
