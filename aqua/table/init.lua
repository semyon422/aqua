local _table = {}

_table.leftequal = function(object1, object2)
	for key in pairs(object1) do
		if object1[key] ~= object2[key] then
			return
		end
	end
	
	return true
end

_table.equal = function(object1, object2)
	return table.leftequal(object1, object2) and table.leftequal(object2, object1)
end

_table.clone = function(object)
	local newObject = {}
	
	for key, value in pairs(object) do
		newObject[key] = value
	end
	
	return newObject
end

return _table
