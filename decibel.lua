local decibel = {}

-- https://en.wikipedia.org/wiki/Decibel

-- Power quantities

---@param p number
---@param p0 number?
---@return number
function decibel.p_to_lp(p, p0)
	return 10 * math.log(p / (p0 or 1), 10)
end

---@param lp number
---@param p0 number?
---@return number
function decibel.lp_to_p(lp, p0)
	return 10 ^ (lp / 10) * (p0 or 1)
end

-- Root-power (field) quantities

---@param f number
---@param f0 number?
---@return number
function decibel.f_to_lf(f, f0)
	return 20 * math.log(f / (f0 or 1), 10)
end

---@param lf number
---@param f0 number?
---@return number
function decibel.lf_to_f(lf, f0)
	return 10 ^ (lf / 20) * (f0 or 1)
end

return decibel
