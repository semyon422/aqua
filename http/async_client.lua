local async_client = {}

function async_client.receive(client, pattern)
	local buffer = {}

	while true do
		local line, err, partial = client:receive(pattern)  -- closed | timeout
		if err == "closed" then
			return nil, "closed"
		end

		local data = line or partial
		if type(pattern) == "number" then
			pattern = pattern - #data
		end

		table.insert(buffer, data)
		if line then
			return table.concat(buffer)
		elseif err == "timeout" then
			coroutine.yield()
		end
	end
end

function async_client.send(client, data)
	local i, j = 1, #data

	while true do
		local bytes_sent, err, last_byte = client:send(data, i, j)  -- closed | timeout
		if err == "closed" then
			return nil, "closed"
		end

		local byte = bytes_sent or last_byte
		i = byte + 1

		if byte == j then
			return true
		elseif err == "timeout" then
			coroutine.yield()
		end
	end
end

return async_client
