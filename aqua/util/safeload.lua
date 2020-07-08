return function(chunk, env)
	if chunk:byte(1) == 27 then
		error("bytecode is not allowed")
	end
	local f, message = loadstring(chunk)
	if not f then
		error(message)
	end
	setfenv(f, env)
	return f
end
