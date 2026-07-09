local class = require("class")
local table_util = require("table_util")
local Websocket = require("web.ws.Websocket")
local ws_util = require("web.ws.util")
local Subprotocol = require("web.ws.Subprotocol")

---@class web.WebsocketConnection
---@operator call: web.WebsocketConnection
---@field options web.WebsocketClientOptions
---@field scheduler web.CosocketScheduler?
---@field closed boolean
---@field write_locked boolean
---@field write_waiters thread[]
---@field reader_thread thread?
local WebsocketConnection = class()

---@param options web.WebsocketClientOptions?
function WebsocketConnection:new(options)
	self.protocol = Subprotocol()
	self.options = options or {}
	self.scheduler = self.options.scheduler
	self.closed = false
	self.write_locked = false
	self.write_waiters = {}
end

---@param err string?
function WebsocketConnection:wakeWriters(err)
	err = err or "closed"
	self.write_locked = false

	local waiters = self.write_waiters
	self.write_waiters = {}
	for _, co in ipairs(waiters) do
		if coroutine.status(co) ~= "dead" then
			local ok, resume_err = coroutine.resume(co, nil, err)
			if not ok then
				error(resume_err, 0)
			end
		end
	end
end

---@param err string?
---@return 1?
---@return string?
function WebsocketConnection:close(err)
	err = err or "closed"
	self.closed = true
	self:wakeWriters(err)

	local scheduler = self.scheduler
	local ws = self.ws
	if ws then
		ws.state = "closed"
	end

	local reader_thread = self.reader_thread
	if scheduler and reader_thread and coroutine.status(reader_thread) ~= "dead" then
		scheduler:cancel(reader_thread, err)
	end
	self.reader_thread = nil

	local soc = self.soc
	self.soc = nil
	self.ws = nil
	if soc then
		return soc:close()
	end
	return 1
end

---@param url string
---@return true?
---@return string?
function WebsocketConnection:connect(url)
	if self.soc or self.ws then
		self:close("reconnecting")
	end

	self.closed = false
	self.write_locked = false
	self.write_waiters = {}

	local ws_client = ws_util.client(self.options)
	self.soc = ws_client.tcp_soc

	local re, err = ws_client:connect(url)
	if not re then
		self:close(err)
		return nil, err
	end

	local ws = Websocket(self.soc, re.req, re.res, "client")
	self.ws = ws
	ws.protocol = self.protocol
	ws.max_payload_len = 1e7

	local ok
	ok, err = ws:handshake()
	if not ok then
		self:close(err)
		return nil, err
	end

	self:startReader()

	return true
end

---@return web.WebsocketState
function WebsocketConnection:getState()
	local ws = self.ws
	return ws and ws:getState() or "connecting"
end

---@return true?
---@return string?
function WebsocketConnection:acquireWriter()
	if self.closed then
		return nil, "closed"
	end

	if not self.scheduler then
		return true
	end

	if not self.write_locked then
		self.write_locked = true
		return true
	end

	-- A websocket frame must be written as one contiguous byte sequence.
	-- Concurrent cosocket sends can yield mid-frame, so later writers wait here.
	local co = coroutine.running()
	if not co then
		return nil, "writer locked"
	end

	table.insert(self.write_waiters, co)
	return coroutine.yield()
end

function WebsocketConnection:releaseWriter()
	if not self.scheduler then
		return
	end

	local waiters = self.write_waiters
	while waiters[1] do
		local co = table.remove(waiters, 1)
		if coroutine.status(co) ~= "dead" then
			local ok, err
			if self.closed then
				ok, err = coroutine.resume(co, nil, "closed")
			else
				ok, err = coroutine.resume(co, true)
			end
			if not ok then
				error(err, 0)
			end
			return
		end
	end

	self.write_locked = false
end

---@param opcode web.WebsocketOpcode
---@param payload string?
---@return integer?
---@return string?
function WebsocketConnection:send(opcode, payload)
	if self.closed then
		return nil, "closed"
	end

	local ws = self.ws
	if not ws then
		return nil, "not connected"
	end

	local ok, err = self:acquireWriter()
	if not ok then
		return nil, err
	end

	local results = table_util.pack(pcall(ws.send, ws, opcode, payload))
	self:releaseWriter()

	if not results[1] then
		error(results[2], 0)
	end

	return table_util.unpack(results, 2, results.n)
end

function WebsocketConnection:startReader()
	if not self.scheduler then
		return
	end

	self.reader_thread = coroutine.create(function()
		local ws = self.ws
		while not self.closed and ws and ws:getState() == "open" do
			local state = ws:getState()
			local ok, err = ws:step()
			if not ok then
				if not self.closed and state ~= "closed" then
					print(("websocket error: %s"):format(err))
				end
				break
			end
		end
	end)
	assert(coroutine.resume(self.reader_thread))
end

function WebsocketConnection:update()
	if self.closed then
		return
	end

	local scheduler = self.scheduler
	if scheduler then
		local ok, err = scheduler:update(0)
		if not ok and err then
			print(("cosocket scheduler error: %s"):format(err))
		end
		return
	end

	local soc = self.soc
	local ws = self.ws
	if not soc or not ws then
		return
	end
	while soc:selectreceive(0) do
		local state = ws:getState()
		local ok, err = ws:step()
		if not ok then
			if state ~= "closed" then
				print(("websocket error: %s"):format(err))
			end
			break
		end
	end
end

return WebsocketConnection
