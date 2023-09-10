local Token = require("typecheck.Token")
local Tokens = require("typecheck.Tokens")

local lexer = {}

local token_patterns = {
	{"id", "[%w_]+"},
	{"leftparan", "%("},
	{"rightparan", "%)"},
	{"vararg", "%.%.%."},
	{"array", "%[%]"},
	{"colon", ":"},
	{"point", "%."},
	{"comma", "%,"},
	{"question", "%?"},
	{"pipe", "|"},
	{"minus", "%-"},
	{"at", "@"},
	{"equal", "="},
	{"asterisk", "*"},
	{"plus", "+"},
	{"{", "{"},
	{"}", "}"},
}

---@param s string
---@return typecheck.Tokens? tokens
---@return string? error_message
function lexer.lex(s)
	local pos = 1
	local tokens = Tokens()

	s = s:match("^%s*(.-)%s*$")
	while pos <= #s do
		local a, b, token
		for _, p in ipairs(token_patterns) do
			a, b, token = s:find("^(" .. p[2] .. ")%s*", pos)
			if token then
				table.insert(tokens, Token(p[1], token, pos))
				break
			end
		end
		if not token then
			return nil, "unknown symbol '" .. s:sub(pos, pos) .. "' at position " .. pos
		end
		pos = b + 1
	end

	tokens.token = tokens[1]

	return tokens
end

return lexer
