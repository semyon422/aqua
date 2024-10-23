local dfa_edge_t = require("web.nginx.dfa_edge_t")

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
	local last = {}  ---@type ngx_http_lua.dfa_edge_t[] t**

	-- cp->pattern.len = len

	if len <= 2 then
		return 0  -- NGX_OK
	end

	for i = 1, len - 1 do
		prefix_len = 1

		while prefix_len <= len - i - 1 do
			if data:sub(1, prefix_len) == data:sub(i + 1, i + prefix_len) then
				if data:sub(prefix_len + 1, prefix_len + 1) == data:sub(prefix_len + 2, prefix_len + 2) then
					prefix_len = prefix_len + 1
					goto continue
				end

				cur_state = i + prefix_len
				new_state = prefix_len + 1

				edge = cp.recovering[cur_state - 2]

				found = false

				if not edge then
					last = cp.recovering[cur_state - 2]
				else
					while true do
						last = edge.next
						if edge.chr == data:sub(prefix_len + 1, prefix_len + 1) then
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

					edge = dfa_edge_t()

					edge.chr = data:sub(prefix_len + 1, prefix_len + 1)
					edge.new_state = new_state
					edge.next = nil

					last = edge
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
