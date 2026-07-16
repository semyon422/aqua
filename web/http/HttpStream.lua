local class = require("class")

---@class web.HttpStreamOptions: web.HttpRequestOptions
---@field client_factory (fun(options: web.HttpClientOptions?): web.HttpClient)?
---@field on_close (fun(stream: web.HttpStream))?

---@class web.HttpStream
---@operator call: web.HttpStream
---@field options web.HttpStreamOptions
---@field client web.HttpClient?
---@field req web.IRequest?
---@field res web.IResponse?
---@field uploaded integer
---@field downloaded integer
---@field request_length integer?
---@field request_chunked boolean
---@field request_headers_sent boolean
---@field upload_finished boolean
---@field response_headers_received boolean
---@field canceled boolean
---@field cancel_err string?
---@field closed boolean
local HttpStream = class()

---@param options web.HttpStreamOptions?
function HttpStream:new(options)
	self.options = options or {}
	self.uploaded = 0
	self.downloaded = 0
	self.request_chunked = false
	self.request_headers_sent = false
	self.upload_finished = false
	self.response_headers_received = false
	self.canceled = false
	self.closed = false
end

---@return boolean
function HttpStream:isCanceled()
	return self.canceled
end

---@return string?
function HttpStream:getCancelError()
	return self.canceled and self.cancel_err or nil
end

---@return true?
---@return string?
function HttpStream:checkCanceled()
	if self.canceled then
		return nil, self.cancel_err
	end
	return true
end

---@param err string?
---@return string?
function HttpStream:mapCancelError(err)
	if self.canceled then
		return self.cancel_err
	end
	return err
end

---@param url string
---@return true?
---@return string?
function HttpStream:connect(url)
	local ok, err = self:checkCanceled()
	if not ok then
		return nil, err
	end

	local options = self.options
	local client_factory = options.client_factory or require("web.http.util").client
	local client = client_factory(options)
	self.client = client
	local req, res
	ok, req, res = pcall(client.connect, client, url, options.connect_host)
	if not ok then
		self.client = nil
		client:close()
		return nil, req
	end

	ok, err = self:checkCanceled()
	if not ok then
		return nil, err
	end

	self.req = req
	self.res = res

	if options.method then
		req.method = options.method
	end
	for k, v in pairs(options.headers or {}) do
		req.headers:set(k, v)
	end

	return true
end

---@param chunk string
function HttpStream:notifyUpload(chunk)
	self.uploaded = self.uploaded + #chunk
	local on_upload = self.options.on_upload
	if on_upload then
		on_upload(self.uploaded, self.request_length, chunk)
	end
end

---@param chunk string
function HttpStream:notifyDownload(chunk)
	self.downloaded = self.downloaded + #chunk
	local res = assert(self.res, "not connected")
	local content_length = res.headers:get("Content-Length")
	local total = tonumber(content_length)
	local on_download = self.options.on_download
	if on_download then
		on_download(self.downloaded, total, chunk)
	end
end

---@param body string
---@return integer?
---@return string?
---@return integer?
function HttpStream:sendBody(body)
	local ok, cancel_err = self:checkCanceled()
	if not ok then
		return nil, cancel_err, 0
	end

	local req = assert(self.req, "not connected")
	if not self.options.method then
		req.method = "POST"
	end
	req:set_length(#body)

	local bytes, err, last_byte = req:send(body)
	if not bytes then
		return nil, self:mapCancelError(err), last_byte
	end

	if #body > 0 then
		self:notifyUpload(body)
	end
	self.upload_finished = true
	return bytes
end

---@param chunks web.HttpChunkSource
---@return true?
---@return string?
function HttpStream:sendChunks(chunks)
	local ok, err = self:startUpload()
	if not ok then
		return nil, err
	end

	local index = 0
	while true do
		local chunk
		if type(chunks) == "function" then
			chunk = chunks()
		else
			index = index + 1
			chunk = chunks[index]
		end
		if not chunk or chunk == "" then
			break
		end

		ok, err = self:sendChunk(chunk)
		if not ok then
			return nil, err
		end
	end

	ok, err = self:finishUpload()
	if not ok then
		return nil, err
	end

	return true
end

---@return true?
---@return string?
function HttpStream:sendHeaders()
	local canceled_ok, cancel_err = self:checkCanceled()
	if not canceled_ok then
		return nil, cancel_err
	end

	if self.request_headers_sent then
		return true
	end

	local req = assert(self.req, "not connected")
	local ok, err = req:send_headers()
	if not ok then
		return nil, self:mapCancelError(err)
	end

	self.request_headers_sent = true
	return true
end

---@param length integer?
---@return true?
---@return string?
function HttpStream:startUpload(length)
	local options = self.options
	local req = assert(self.req, "not connected")

	if not options.method then
		req.method = "POST"
	end

	length = length or options.request_length
	self.request_length = length
	if length then
		req:set_length(length)
		self.request_chunked = false
	else
		req:set_chunked_encoding()
		self.request_chunked = true
	end

	return self:sendHeaders()
end

---@param chunk string
---@return integer?
---@return string?
---@return integer?
function HttpStream:sendChunk(chunk)
	local canceled_ok, cancel_err = self:checkCanceled()
	if not canceled_ok then
		return nil, cancel_err, 0
	end

	if not self.request_headers_sent then
		local ok, err = self:startUpload()
		if not ok then
			return nil, err, 0
		end
	end

	local req = assert(self.req, "not connected")
	local bytes, err, last_byte = req:send(chunk)
	if not bytes then
		return nil, self:mapCancelError(err), last_byte
	end

	self:notifyUpload(chunk)

	return bytes
end

---@return integer?
---@return string?
---@return integer?
function HttpStream:finishUpload()
	local canceled_ok, cancel_err = self:checkCanceled()
	if not canceled_ok then
		return nil, cancel_err, 0
	end

	if self.upload_finished then
		return 0
	end

	if not self.request_headers_sent then
		local ok, err = self:startUpload()
		if not ok then
			return nil, err, 0
		end
	end

	if self.request_chunked then
		local req = assert(self.req, "not connected")
		local bytes, err, last_byte = req:send("")
		if not bytes then
			return nil, self:mapCancelError(err), last_byte
		end
	end

	self.upload_finished = true
	return 0
end

---@return true?
---@return string?
function HttpStream:receiveHeaders()
	local canceled_ok, cancel_err = self:checkCanceled()
	if not canceled_ok then
		return nil, cancel_err
	end

	if self.response_headers_received then
		return true
	end

	local res = assert(self.res, "not connected")
	local ok, err = res:receive_headers()
	if not ok then
		return nil, self:mapCancelError(err)
	end

	self.response_headers_received = true
	return true
end

---@param size integer?
---@return string?
---@return string?
---@return string?
function HttpStream:receiveChunk(size)
	local ok, err = self:receiveHeaders()
	if not ok then
		return nil, err, ""
	end

	local res = assert(self.res, "not connected")
	local chunk, receive_err, partial = res:receive(size or self.options.chunk_size or 64 * 1024)
	receive_err = self:mapCancelError(receive_err)
	local data = chunk or partial
	if data and #data > 0 then
		self:notifyDownload(data)
	end
	if not chunk and partial and #partial > 0 and receive_err == "closed" then
		return partial
	end
	return chunk, receive_err, partial
end

---@return string?
---@return string?
function HttpStream:receiveBody()
	---@type string[]
	local chunks = {}
	while true do
		local chunk, err = self:receiveChunk()
		if not chunk then
			if err == "closed" or err == nil then
				break
			end
			return nil, err
		end
		table.insert(chunks, chunk)
	end
	return table.concat(chunks)
end

---@param err string?
---@return 1?
---@return string?
function HttpStream:cancel(err)
	if not self.canceled then
		self.canceled = true
		self.cancel_err = err or "canceled"
	end
	return self:close()
end

---@return 1?
---@return string?
function HttpStream:close()
	if self.closed then
		return 1
	end
	self.closed = true

	local client = self.client
	self.client = nil
	self.req = nil
	self.res = nil
	local on_close = self.options.on_close
	if on_close then
		on_close(self)
	end
	if client then
		return client:close()
	end
	return 1
end

return HttpStream
