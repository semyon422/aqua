local path_util = {}

function path_util.fix_illegal(s, c)
	return s:gsub('[/\\?%*:|"<>]', c or "_")
end

return path_util
