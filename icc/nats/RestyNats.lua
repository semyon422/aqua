local class = require("class")

---@class nats.Message
---@field sid string
---@field subject string
---@field reply_to string?
---@field payload string

---@class nats.Socket
---@field send fun(self: nats.Socket, data: string): integer?, string?
---@field receiveany fun(self: nats.Socket, size: integer): string?, string?

---@class nats.Client
---@field sock nats.Socket
---@field closing boolean
---@field subscribers {[integer]: fun(message: nats.Message)}
---@field subscriber_id_map {[string]: integer}
---@field subscriber_id integer
---@field publish fun(self: nats.Client, opts: {subject: string, reply_to?: string, payload?: string}): boolean?, string?
---@field subscribe fun(self: nats.Client, subject: string, cb: fun(message: nats.Message)): boolean?, string?
---@field close fun(self: nats.Client)

---@type {connect: fun(options: table): nats.Client?, string?}
local nats_client = require("resty.nats.client")

---@class nats.ProtocolParser
---@field parse fun(self: nats.ProtocolParser, line: string): string?

---@class nats.ProtocolParserModule
---@field new fun(callback: fun(message_type: string, message: nats.Message?)): nats.ProtocolParser
---@field MESSAGE_TYPE {[string]: string}

---@type nats.ProtocolParserModule
local protocol_parser = require("resty.nats.protocols.parser")
---@type {encode: fun(message: {sid: integer}): string}
local unsubscribe_protocol = require("resty.nats.protocols.unsub")

---@class nats.RestyNats: nats.INats
---@field host string
---@field port integer
---@field cli nats.Client? underlying NATS client
---@field connected boolean connection state (true=connected, false=failed, nil=not tried)
---@field connect_failed boolean true if initial connect() failed (cached to avoid retry storms)
---@field receive_thread any? receive loop thread handle
---@operator call: nats.RestyNats
local RestyNats = class()

--- Singleton instance.
---@type nats.RestyNats?
RestyNats._instance = nil

---@param opts {host?: string, port?: integer}?
function RestyNats:new(opts)
	opts = opts or {}
	self.host = opts.host or "127.0.0.1"
	self.port = opts.port or 4222
	self.cli = nil
	self.connected = nil
	self.connect_failed = false
	self.receive_thread = nil
end

--- Start the underlying NATS connection and receive loop.
--- Handles socket timeouts gracefully by sleeping and retrying.
--- On initial connect failure, caches the error so subsequent calls don't retry.
--- On receive loop death, resets state so subsequent calls can reconnect.
---@return nats.Client? client
---@return string? err
function RestyNats:start()
	if self.cli then
		return self.cli
	end
	if self.connect_failed then
		return nil, "NATS not connected"
	end

	local cli, err = nats_client.connect({
		host = self.host,
		port = self.port,
		timeout = 60000, -- 1 minute
		keepalive = false,
	})
	if not cli then
		self.connect_failed = true
		print("[nats] failed to connect: " .. tostring(err))
		return nil, tostring(err)
	end
	self.cli = cli
	self.connected = true

	-- Custom receive loop that handles socket timeouts gracefully.
	-- On exit (error or worker shutdown), resets connection state so callers can retry.
	self.receive_thread = ngx.thread.spawn(function()
		local sock = cli.sock
		local parser = protocol_parser.new(function(message_type, message)
			if message_type == protocol_parser.MESSAGE_TYPE.PING then
				sock:send("PONG\r\n")
			elseif message_type == protocol_parser.MESSAGE_TYPE.MSG then
				local msg = assert(message)
				local sid = assert(tonumber(msg.sid))
				local subscriber = cli.subscribers[sid]
				if subscriber then subscriber(msg) end
			elseif message_type == protocol_parser.MESSAGE_TYPE.HMSG then
				local msg = assert(message)
				local sid = assert(tonumber(msg.sid))
				local subscriber = cli.subscribers[sid]
				if subscriber then subscriber(msg) end
			end
		end)

		while not ngx.worker.exiting() do
			if cli.closing then break end
			local line, err = sock:receiveany(70)
			if not line then
				if err == "timeout" then
					ngx.sleep(0.1)
				else
					print("[nats] receive error:", err)
					break
				end
			else
				local parse_err = parser:parse(line)
				if parse_err then
					print("[nats] parse error:", parse_err)
					break
				end
			end
		end

		-- Connection died — reset state so subsequent calls can reconnect.
		-- Do NOT set connect_failed; that only blocks initial connect attempts.
		self.cli = nil
		self.connected = false
		self.receive_thread = nil
		print("[nats] receive loop exited — will reconnect on next call")
	end)

	return cli
end

--- Get the underlying NATS client (starts connection if needed).
--- @private
---@return nats.Client? client
---@return string? err
function RestyNats:client()
	return self:start()
end

---@param opts {subject: string, reply_to?: string, payload?: string}
---@return boolean?, string?
function RestyNats:publish(opts)
	local client, err = self:client()
	if not client then
		return nil, err or "NATS not connected"
	end
	return client:publish(opts)
end

---@param subject string
---@param cb fun(message: {subject: string, reply_to?: string, payload: string})
---@return boolean?, string?, integer?
function RestyNats:subscribe(subject, cb)
	local client, err = self:client()
	if not client then
		return nil, err or "NATS not connected"
	end
	local ok, sub_err = client:subscribe(subject, cb)
	if not ok then
		return nil, sub_err
	end
	-- subscriber_id was incremented inside client:subscribe()
	return ok, nil, client.subscriber_id
end

---@param sid integer
---@return boolean?, string?
function RestyNats:unsubscribe(sid)
	local client, err = self:client()
	if not client then
		return nil, err or "NATS not connected"
	end
	client.subscribers[sid] = nil
	-- Clean up subscriber_id_map: remove any entry pointing to this sid
	for subject, mapped_sid in pairs(client.subscriber_id_map) do
		if mapped_sid == sid then
			client.subscriber_id_map[subject] = nil
			break
		end
	end
	local bytes, send_err = client.sock:send(unsubscribe_protocol.encode({sid = sid}) .. "\r\n")
	if not bytes then
		return nil, "failed to send UNSUB message: " .. send_err
	end
	return true
end

function RestyNats:close()
	if self.cli then
		self.cli:close()
		self.cli = nil
	end
	self.connected = nil
	self.connect_failed = false
	self.receive_thread = nil
end

--- Check if the connection is alive.
--- Returns false if never connected, connection failed, or receive loop has died.
--- Does not trigger a reconnection attempt.
---@return boolean
function RestyNats:health()
	return self.connected == true and self.cli ~= nil
end

--- Get or create the singleton instance.
---@param opts {host?: string, port?: integer}?
---@return nats.RestyNats
function RestyNats.instance(opts)
	if not RestyNats._instance then
		RestyNats._instance = RestyNats(opts)
	end
	return RestyNats._instance
end

return RestyNats
