local class = require("class")
local nats_client = require("resty.nats.client")
local protocol_parser = require("resty.nats.protocols.parser")

---@class nats.RestyNats: nats.INats
---@field host string
---@field port integer
---@field cli any? underlying NATS client
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
end

--- Start the underlying NATS connection and receive loop.
--- Handles socket timeouts gracefully by sleeping and retrying.
---@return any client
function RestyNats:start()
	if self.cli then
		return self.cli
	end

	local cli, err = nats_client.connect({
		host = self.host,
		port = self.port,
		timeout = 60000, -- 1 minute
		keepalive = false,
	})
	if not cli then
		error("failed to connect to NATS: " .. tostring(err))
	end
	self.cli = cli

	-- Custom receive loop that handles socket timeouts gracefully.
	ngx.thread.spawn(function()
		local sock = cli.sock
		local parser = protocol_parser.new(function(type, message)
			if type == protocol_parser.MESSAGE_TYPE.PING then
				sock:send("PONG\r\n")
			elseif type == protocol_parser.MESSAGE_TYPE.MSG then
				local subscriber = cli.subscribers[tonumber(message.sid)]
				if subscriber then subscriber(message) end
			elseif type == protocol_parser.MESSAGE_TYPE.HMSG then
				local subscriber = cli.subscribers[tonumber(message.sid)]
				if subscriber then subscriber(message) end
			end
		end)

		while not ngx.worker.exiting() do
			if cli.closing then break end
			local line, err = sock:receiveany(70)
			if not line then
				if err == "timeout" then
					ngx.sleep(0.1)
				else
					print("nats receive error:", err)
					break
				end
			else
				local parse_err = parser:parse(line)
				if parse_err then
					print("nats parse error:", parse_err)
					break
				end
			end
		end
	end)

	return cli
end

--- Get the underlying NATS client (starts connection if needed).
--- @private
---@return any client
function RestyNats:client()
	self:start()
	return self.cli
end

---@param opts {subject: string, reply_to?: string, payload?: string}
---@return boolean?, string?
function RestyNats:publish(opts)
	return self:client():publish(opts)
end

---@param subject string
---@param cb fun(message: {subject: string, reply_to?: string, payload: string})
---@return boolean?, string?
function RestyNats:subscribe(subject, cb)
	return self:client():subscribe(subject, cb)
end

---@param subject string
---@return boolean?, string?
function RestyNats:unsubscribe(subject)
	return self:client():unsubscribe(subject)
end

function RestyNats:close()
	if self.cli then
		self.cli:close()
		self.cli = nil
	end
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
