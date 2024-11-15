local class = require("class")

---@class ngx.chain_t
---@operator call: ngx.chain_t
---@field buf ngx.buf_t ngx_buf_t*
---@field next ngx.chain_t ngx_chain_t*
local ngx_chain_t = class()

---@return boolean
function ngx_chain_t:is_looped()
	---@type {[ngx.chain_t]: true}
	local seen = {}

	local chain = self
	while chain do
		seen[chain] = true
		chain = chain.next
		if seen[chain] then
			return true
		end
	end

	return false
end

---@return string
function ngx_chain_t:__tostring()
	---@type string[]
	local out = {}

	---@type {[ngx.chain_t]: true}
	local seen = {}

	local chain = self
	while chain do
		table.insert(out, tostring(chain.buf))
		seen[chain] = true
		chain = chain.next
		if seen[chain] then
			table.insert(out, "loop")
			break
		end
	end

	return table.concat(out, "->")
end

return ngx_chain_t
