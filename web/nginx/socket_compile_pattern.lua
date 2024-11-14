local ffi = require("ffi")
local dfa_edge_t = require("web.nginx.dfa_edge_t")

ffi.cdef[[
	int memcmp(const void * p1, const void * p2, size_t n);
]]

---@param data ffi.cdata*
---@param len integer
---@param cp ngx_http_lua.socket_compiled_pattern_t
local function socket_compile_pattern(data, len, cp)
	local last_t, last_k  ---@type table, integer|"next"

	cp.pattern.data = data
	cp.pattern.len = len

	if len <= 2 then
		return
	end

	for i = 1, len - 1 do
		local prefix_len = 1

		while prefix_len <= len - i - 1 do
			if ffi.C.memcmp(data, data + i, prefix_len) == 0 then
				if data[prefix_len] == data[i + prefix_len] then
					prefix_len = prefix_len + 1
					goto continue
				end

				local cur_state = i + prefix_len
				local new_state = prefix_len + 1

				if not cp.recovering then
					cp.recovering = {}  -- 0-indexed, size of (len - 2)
				end

				local edge = cp.recovering[cur_state - 2]

				local found = false

				if not edge then
					last_t, last_k = cp.recovering, cur_state - 2
				else
					while edge do
						last_t, last_k = edge, "next"

						if edge.chr == data[prefix_len] then
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
					edge = dfa_edge_t()

					edge.chr = data[prefix_len]
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
