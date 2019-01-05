return function(try, catch)
	local status, result = pcall(try)
	if not status then return catch(result) end
	return result
end