local thread = require("thread")
thread.shared.download = {}

local fs_util = {}

---@param archive string|love.FileData
---@param path string
---@return true?
---@return string?
function fs_util.extractAsync(archive, path)
	require("love.filesystem")
	local rcopy = require("rcopy")
	local mount = path .. "_temp"

	if type(archive) == "string" then
		if not love.filesystem.mountFullPath(archive, mount, "read", true) then
			return nil, "failed to mount full path"
		end
	elseif not love.filesystem.mount(archive, mount, true) then
		return nil, "failed to mount archive"
	end

	rcopy(mount, path)

	if type(archive) == "string" then
		if not love.filesystem.unmountFullPath(archive) then
			return nil, "failed to unmount full path"
		end
	elseif not love.filesystem.unmount(archive) then
		return nil, "failed to unmount archive"
	end

	return true
end
fs_util.extractAsync = thread.async(fs_util.extractAsync)

---@param url string
---@return string?
---@return (string|number)?
---@return table?
---@return string?
function fs_util.downloadAsync(url)
	local http_util = require("web.http.util")
	local thread = require("thread")

	thread.shared.download[url] = {
		size = 0,
		total = 0,
		speed = 0,
	}
	local shared = thread.shared.download[url]

	local client = http_util.client()
	local ok, req, res = pcall(client.connect, client, url)
	if not ok then
		client:close()
		return nil, req
	end

	local bytes, err = req:send("")
	if not bytes then
		client:close()
		return nil, err
	end

	ok, err = res:receive_headers()
	if not ok then
		client:close()
		return nil, err
	end

	local code = res.status
	local headers = {}
	for _, key in ipairs(res.headers:getKeys()) do
		local name = res.headers.header_names[key] or key
		local values = res.headers.headers[key]
		headers[name] = #values == 1 and values[1] or values
	end

	if code >= 400 then
		client:close()
		return nil, code, headers, "HTTP " .. code
	end

	local total = 0
	local t = {}
	local time
	local function sink(chunk)
		if chunk == nil or chunk == "" then
			return true
		end

		time = time or love.timer.getTime()
		total = total + #chunk
		shared.total = total
		shared.speed = total / (love.timer.getTime() - time)

		table.insert(t, chunk)

		return true
	end

	while true do
		local chunk, receive_err, partial = res:receive(64 * 1024)
		if not chunk then
			if partial and #partial > 0 then
				sink(partial)
			end
			if receive_err == "closed" or receive_err == nil then
				break
			end
			client:close()
			return nil, receive_err, headers
		end
		sink(chunk)
	end

	client:close()
	return table.concat(t), code, headers, "HTTP " .. code
end
fs_util.downloadAsync = thread.async(fs_util.downloadAsync)

return fs_util
