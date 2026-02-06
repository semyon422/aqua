local dpairs = require("dpairs")

local valid = {}

---@class valid.Errors
---@field [string|integer] string|true|false|valid.Errors

---@alias util.ValidationFunc fun(v: any?): boolean?, string|valid.Errors?

function valid.index(v)
	if type(v) ~= "number" then
		return nil, "not a number"
	elseif v ~= v then
		return nil, "NaN"
	elseif math.abs(v) == math.huge then
		return nil, "infinity"
	elseif v ~= math.floor(v) then
		return nil, "not an integer"
	elseif v < 1 then
		return nil, "less than one"
	end

	return true
end

---@param schema {[string]: util.ValidationFunc}
---@param table_err string?
---@return util.ValidationFunc
function valid.struct(schema, table_err)
	---@param t any?
	---@return true?
	---@return string|valid.Errors?
	return function(t)
		if type(t) ~= "table" then
			return nil, table_err
		end
		---@cast t {[any]: any}

		---@type valid.Errors
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

---@param f util.ValidationFunc
---@param max_size integer
---@param table_err string?
---@return util.ValidationFunc
function valid.array(f, max_size, table_err)
	---@param t {[any]: any?}?
	---@return true?
	---@return string|valid.Errors?
	return function(t)
		if type(t) ~= "table" then
			return nil, table_err
		end
		---@cast t {[any]: any}

		---@type valid.Errors
		local errs = {}

		local max_key = 0
		local count = 0
		for k, v in pairs(t) do
			if not valid.index(k) then
				errs[k] = false
			else
				---@cast k integer
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

---@param fs util.ValidationFunc[]
---@param table_err string?
---@return util.ValidationFunc
function valid.tuple(fs, table_err)
	---@param t {[any]: any?}?
	---@return true?
	---@return string|valid.Errors?
	return function(t)
		if type(t) ~= "table" then
			return nil, table_err
		end
		---@cast t {[any]: any}

		---@type valid.Errors
		local errs = {}

		for k, v in pairs(t) do
			local f = fs[k]
			if not valid.index(k) or not f then
				errs[k] = false
			else
				---@cast k integer
				local ok, err = f(v)
				if not ok then
					errs[k] = err or true
				end
			end
		end

		for i, f in ipairs(fs) do
			local v = t[i]
			if v == nil then
				local ok, err = f(v)
				if not ok then
					errs[i] = err or true
				end
			end
		end

		if next(errs) then
			return nil, errs
		end

		return true
	end
end

---@param kf util.ValidationFunc
---@param vf util.ValidationFunc
---@param max_size integer
---@param table_err string?
---@return util.ValidationFunc
function valid.map(kf, vf, max_size, table_err)
	---@param t any?
	---@return true?
	---@return string|valid.Errors?
	return function(t)
		if type(t) ~= "table" then
			return nil, table_err
		end
		---@cast t {[any]: any}

		---@type valid.Errors
		local errs = {}

		local count = 0
		for k, v in pairs(t) do
			local ok, err = kf(k)
			if not ok then
				errs[k] = err or false
			else
				ok, err = vf(v)
				if not ok then
					errs[k] = err or true
				end
				count = count + 1
			end
		end

		if count > max_size then
			return nil, "too long"
		elseif next(errs) then
			return nil, errs
		end

		return true
	end
end

---@param values any[]
---@return util.ValidationFunc
function valid.one_of(values)
	return function(v)
		for i, _v in ipairs(values) do
			if v == _v then
				return true
			end
		end
		return nil, "not one of " .. #values .. " values"
	end
end

---@param f util.ValidationFunc
---@return util.ValidationFunc
function valid.optional(f)
	return function(v)
		if v == nil then
			return true
		end
		return f(v)
	end
end

---@return util.ValidationFunc
function valid.any()
	return function(v)
		return v ~= nil
	end
end

---@param ... util.ValidationFunc
---@return util.ValidationFunc
function valid.compose(...)
	local n = select("#", ...)
	local fs = {...}
	---@return true?
	---@return string|valid.Errors?
	return function(v)
		for i = 1, n do
			local ok, err = fs[i](v)
			if not ok then
				return nil, err
			end
		end
		return true
	end
end

---@param errs string|valid.Errors?
---@param fmt string?
---@param buf string[]?
---@param prefix string?
---@return string[]
function valid.flatten_errors(errs, fmt, buf, prefix)
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
		elseif v == false then
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
		valid.flatten_errors(t, fmt, buf, prefix .. k .. ".")
	end

	return buf
end

---@generic T
---@param ok T?
---@param err string|valid.Errors?
---@return T?
---@return string[]?
function valid.flatten(ok, err)
	if ok then
		return ok
	end
	return ok, valid.flatten_errors(err)
end

---@param f util.ValidationFunc
---@return fun(v?: any): boolean?, string[]?
function valid.wrap_flatten(f)
	return function(...)
		return valid.flatten(f(...))
	end
end

--------------------------------------------------------------------------------

---@param err string|valid.Errors?
---@return string?
function valid.format_errors(err)
	if type(err) == "table" then
		err = table.concat(valid.flatten_errors(err), ", ")
	end
	---@cast err string
	return err
end

---@generic T
---@param ok T?
---@param err string|valid.Errors?
---@return T?
---@return string?
function valid.format(ok, err)
	if ok then
		return ok
	end
	return ok, valid.format_errors(err)
end

---@param f util.ValidationFunc
---@return fun(v?: any): boolean?, string?
function valid.wrap_format(f)
	return function(...)
		return valid.format(f(...))
	end
end

--------------------------------------------------------------------------------

---@param a {[any]: any} reference value
---@param b {[any]: any}
---@param buf string[]?
---@param prefix string?
function valid.equals(a, b, buf, prefix)
	buf = buf or {}
	prefix = prefix or ""

	---@type {[string]: true}
	local keys = {}

	for k, v in dpairs(a) do
		keys[k] = true

		local _v = b[k]
		local ta, tb = type(v), type(_v)

		if ta == "number" then
			v = ("%0.20g"):format(v)
		end
		if tb == "number" then
			_v = ("%0.20g"):format(_v)
		end

		if _v == nil then
			table.insert(buf, ("missing '%s'"):format(prefix .. k))
		elseif ta ~= tb then
			table.insert(buf, ("type '%s': %q, %q"):format(prefix .. k, ta, tb))
		elseif ta ~= "table" then
			if v == v and v ~= _v then
				table.insert(buf, ("value '%s': %q, %q"):format(prefix .. k, v, _v))
			end
		else
			valid.equals(v, _v, buf, prefix .. k .. ".")
		end
	end

	for k, v in dpairs(b) do
		if not keys[k] then
			table.insert(buf, ("extra '%s'"):format(prefix .. k))
		end
	end

	if #buf ~= 0 then
		return nil, table.concat(buf, ", ")
	end

	return true
end

return valid
