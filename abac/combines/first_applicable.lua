return function(a, b)
	if
		a == "permit" and b == "not_applicable" or
		b == "permit" and a == "not_applicable"
	then
		return "permit"
	end
	if
		a == "deny" and b == "not_applicable" or
		b == "deny" and a == "not_applicable"
	then
		return "deny"
	end
	if a == "permit" and b == "deny" or a == "permit" and b == "permit" then
		return "permit"
	end
	if a == "deny" and b == "permit" or a == "deny" and b == "deny" then
		return "deny"
	end
	if a == "not_applicable" and b == "not_applicable" then
		return "not_applicable"
	end
	return "indeterminate"
end
