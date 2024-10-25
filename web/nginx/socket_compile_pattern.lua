local dfa_edge_t = require("web.nginx.dfa_edge_t")

local print_debug = false

---@param s string
---@param i integer
---@return string
local function subchar0(s, i)
	return s:sub(i + 1, i + 1)
end

---@param data string
---@param cp ngx_http_lua.socket_compiled_pattern_t
local function socket_compile_pattern(data, cp)
	local len = #data

	local prefix_len  ---@type integer
	local found  ---@type integer
	local cur_state, new_state  ---@type integer, integer

	local edge  ---@type ngx_http_lua.dfa_edge_t t*
	local last_t, last_k = {}, 0  ---@type table, integer|"next"

	if len <= 2 then
		return
	end

	for i = 1, len - 1 do
		prefix_len = 1

		while prefix_len <= len - i - 1 do
			if data:sub(1, prefix_len) == data:sub(i + 1, i + prefix_len) then
				if subchar0(data, prefix_len) == subchar0(data, prefix_len + i) then
					prefix_len = prefix_len + 1
					goto continue
				end

				cur_state = i + prefix_len
				new_state = prefix_len + 1

				if not cp.recovering then
					cp.recovering = {}  -- 0-indexed, size of (len - 2)
				end

				edge = cp.recovering[cur_state - 2]

				found = false

				if not edge then
					last_t, last_k = cp.recovering, cur_state - 2
				else
					while edge do
						last_t, last_k = edge, "next"

						if edge.chr == subchar0(data, prefix_len) then
							found = true
							if edge.new_state < new_state then
								edge.new_state = new_state  -- idk how to cover his line
							end
							break
						end

						edge = edge.next
					end
				end

				if not found then
					if print_debug then
						print((
							"lua tcp socket read until recovering point:" ..
							" on state %d (%s), if next is '%s', then " ..
							"recover to state %d (%s)"
						):format(
							cur_state, subchar0(data, cur_state),
							subchar0(data, prefix_len),
							new_state, subchar0(data, new_state)
						))
					end

					edge = dfa_edge_t()

					edge.chr = subchar0(data, prefix_len)
					edge.new_state = new_state
					edge.next = nil

					last_t[last_k] = edge
				end

				break
			end

			do break end

			::continue::
		end
	end
end

return socket_compile_pattern
