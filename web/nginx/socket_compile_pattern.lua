local dfa_edge_t = require("web.nginx.dfa_edge_t")

local print_debug = false

---@param s string
---@param i integer
---@return string
local function subchar(s, i)
	return s:sub(i, i)
end

---@param data string
---@param cp ngx_http_lua.socket_compiled_pattern_t
---@return integer
local function socket_compile_pattern(data, cp)
	local len = #data

	local prefix_len  ---@type integer
	local size  ---@type integer
	local found  ---@type integer
	local cur_state, new_state  ---@type integer, integer

	local edge  ---@type ngx_http_lua.dfa_edge_t t*
	local last_offset = 0

	-- cp->pattern.len = len

	if len <= 2 then
		return 0  -- NGX_OK
	end

	for i = 1, len - 1 do
		prefix_len = 1

		while prefix_len <= len - i - 1 do
			if data:sub(1, prefix_len) == data:sub(i + 1, i + prefix_len) then
				if subchar(data, prefix_len + 1) == subchar(data, prefix_len + 1 + i) then
					prefix_len = prefix_len + 1
					goto continue
				end

				cur_state = i + prefix_len
				new_state = prefix_len + 1

				if not cp.recovering then
					cp.recovering = {}
					for j = 0, len - 2 - 1 do
						cp.recovering[j] = nil  -- NULL
					end
				end

				edge = cp.recovering[cur_state - 2]

				found = false

				if not edge then
					last_offset = cur_state - 2
				else
					while edge do
						last_offset = edge

						if edge.chr == subchar(data, prefix_len + 1) then
							found = true
							if edge.new_state < new_state then
								edge.new_state = new_state
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
							cur_state,
							data:sub(cur_state + 1, cur_state + 1),
							data:sub(prefix_len + 1, prefix_len + 1),
							new_state,
							data:sub(new_state + 1, new_state + 1)
						))
					end

					edge = dfa_edge_t()

					edge.chr = subchar(data, prefix_len + 1)
					edge.new_state = new_state
					edge.next = nil

					if type(last_offset) == "number" then
						cp.recovering[last_offset] = edge
					elseif type(last_offset) == "table" then
						last_offset.next = edge
					end
				end

				break
			end

			do break end

			::continue::
		end
	end

	return 0  -- NGX_OK
end

return socket_compile_pattern
