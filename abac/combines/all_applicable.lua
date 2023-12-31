return function(a, b)
	if a == "permit" and b == "permit" then
		return "permit"
	end
	if a == "deny" and b == "deny" then
		return "deny"
	end
	if a == "indeterminate" or b == "indeterminate" then
		return "indeterminate"
	end
	if a == "not_applicable" or b == "not_applicable" then
		return "not_applicable"
	end
	return "indeterminate"
end
