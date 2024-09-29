local thread = require("thread")
thread.shared.download = {}

local fs_util = {}

---@param archive string|love.FileData
---@param path string
---@return true?
---@return string?
function fs_util.extractAsync(archive, path)
	require("love.filesystem")
	local physfs = require("physfs")
	local rcopy = require("rcopy")
	local mount = path .. "_temp"

	local fs = love.filesystem
	if type(archive) == "string" then
		fs = physfs
	end

	if not fs.mount(archive, mount, true) then
		return nil, physfs.getLastError()
	end

	rcopy(mount, path)

	if not fs.unmount(archive) then
		return nil, physfs.getLastError()
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
	local http = require("http")
	local ltn12 = require("ltn12")
	local thread = require("thread")

	local one, code, headers, status_line = http.request({
		url = url,
		method = "HEAD",
		sink = ltn12.sink.null(),
	})
	if not one then
		return nil, code, headers, status_line
	end
	if code >= 300 then
		return nil, code, headers, status_line
	end

	local size
	for header, value in pairs(headers) do
		header = header:lower()
		if header == "content-length" then
			size = tonumber(value) or size
		end
	end

	thread.shared.download[url] = {
		size = size,
		total = 0,
		speed = 0,
	}
	local shared = thread.shared.download[url]

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

	one, code, headers, status_line = http.request({
		url = url,
		method = "GET",
		sink = sink,
	})
	if not one then
		return nil, code, headers, status_line
	end
	if code >= 400 then
		return nil, code, headers, status_line
	end

	return table.concat(t), code, headers, status_line
end
fs_util.downloadAsync = thread.async(fs_util.downloadAsync)

return fs_util
