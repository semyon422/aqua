return function(time)
	local hours = math.floor(time / 3600)
	local minutes = math.floor(time % 3600 / 60)
	local seconds = math.floor(time % 60)

	if time >= 3600 then
		return ("%02d:%02d:%02d"):format(hours, minutes, seconds)
	elseif time >= 60 then
		return ("%02d:%02d"):format(minutes, seconds)
	elseif time >= 0 then
		return ("%02d"):format(seconds)
	end
end
