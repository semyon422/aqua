local class = require("class")
local lexer = require("typecheck.lexer")
local Type = require("typecheck.Type")

local nil_type = Type(nil)

local tablecheck = class()

function tablecheck:new(types)
	local tokens = assert(lexer.lex(types))
	self.param_names, self.param_types = assert(tokens:parse_params())
	self.params_map = {}
	for i, name in ipairs(self.param_names) do
		self.params_map[name] = self.param_types[i]
	end
end

local exp_got = "bad argument '%s' (%s expected, got %s)"

function tablecheck:__call(t)
	local params_map = self.params_map
	local keys = {}
	for k in pairs(t) do
		keys[k] = true
	end
	for k in pairs(params_map) do
		keys[k] = true
	end
	for k in pairs(keys) do
		local _type = params_map[k] or nil_type
		local v = t[k]
		assert(_type:check(v), exp_got:format(k, _type, type(v)))
	end
	return t
end

return tablecheck
