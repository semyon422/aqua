local dpairs = require("dpairs")

local valid = {}

---@alias util.Errors {[string]: string|true|util.Errors}

---@param schema {[string]: fun(v: any?): boolean?, string|util.Errors?}
---@param table_err string?
---@return fun(v: any?): boolean?, string|util.Errors?
function valid.create(schema, table_err)
	---@param t {[string]: any?}?
	return function(t)
		if type(t) ~= "table" then
			return nil, table_err
		end

		---@type util.Errors
		local errs = {}

		for k, f in pairs(schema) do
			local ok, err = f(t[k])
			if not ok then
				errs[k] = err or true
			end
		end

		for k in pairs(t) do
			if not schema[k] then
				errs[k] = "not nil"
			end
		end

		if next(errs) then
			return nil, errs
		end

		return true
	end
end

---@param errs string|util.Errors?
---@param fmt string?
---@param buf string[]?
---@param prefix string?
function valid.flatten(errs, fmt, buf, prefix)
	if not errs then
		return {}
	end

	if type(errs) == "string" then
		errs = {errs}
	end

	fmt = "%s is %s"

	buf = buf or {}
	prefix = prefix or ""

	---@type string[]
	local table_keys = {}
	for k, v in dpairs(errs) do
		if v == true then
			v = "invalid"
		end
		if type(v) == "string" then
			table.insert(buf, prefix .. fmt:format(k, v))
		elseif type(v) == "table" then
			table.insert(table_keys, k)
		end
	end

	for _, k in ipairs(table_keys) do
		local t = errs[k]
		---@cast t -string, -true
		valid.flatten(t, fmt, buf, prefix .. k .. ".")
	end

	return buf
end

return valid
