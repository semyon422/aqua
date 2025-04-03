local dpairs = require("dpairs")

local valid = {}

---@alias util.Errors {[string|integer]: string|true|false|util.Errors}

---@param schema {[string]: fun(v: any?): boolean?, string|util.Errors?}
---@param table_err string?
---@return fun(v: any?): boolean?, string|util.Errors?
function valid.struct(schema, table_err)
	---@param t any?
	return function(t)
		if type(t) ~= "table" then
			return nil, table_err
		end
		---@cast t {[any]: any}

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
				errs[k] = false
			end
		end

		if next(errs) then
			return nil, errs
		end

		return true
	end
end

---@param f fun(v: any?): boolean?, string|util.Errors?
---@param max_size integer
---@param table_err string?
---@return fun(v: any?): boolean?, string|util.Errors?
function valid.array(f, max_size, table_err)
	---@param t {[any]: any?}?
	return function(t)
		if type(t) ~= "table" then
			return nil, table_err
		end
		---@cast t {[any]: any}

		---@type util.Errors
		local errs = {}

		local max_key = 0
		local count = 0
		for k, v in pairs(t) do
			if type(k) ~= "number" or k ~= math.floor(k) or k <= 0 then
				errs[k] = false
			else
				local ok, err = f(v)
				if not ok then
					errs[k] = err or true
				end
				count = count + 1
				max_key = math.max(max_key, k)
			end
		end

		if count ~= max_key then
			return nil, "sparse"
		elseif count > max_size then
			return nil, "too long"
		elseif next(errs) then
			return nil, errs
		end

		return true
	end
end

---@param f fun(v: any?): boolean?, string|util.Errors?
---@return fun(v: any?): boolean?, string|util.Errors?
function valid.optional(f)
	return function(v)
		if v == nil then
			return true
		end
		return f(v)
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
		elseif v == true then
			v = "not nil"
		end
		if type(v) == "string" then
			table.insert(buf, prefix .. fmt:format(k, v))
		elseif type(v) == "table" then
			table.insert(table_keys, k)
		end
	end

	for _, k in ipairs(table_keys) do
		local t = errs[k]
		---@cast t -string, -boolean
		valid.flatten(t, fmt, buf, prefix .. k .. ".")
	end

	return buf
end

return valid
