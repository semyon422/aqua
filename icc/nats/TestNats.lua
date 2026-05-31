local class = require("class")

---@alias nats.SubjectMatcher fun(subject: string): boolean

---@class nats.TestNats: nats.INats
---@field published {[integer]: {subject: string, reply_to?: string, payload?: string}}
---@field subscribers {[integer]: {subject: string, callback: function, match: nats.SubjectMatcher}}
---@field pending {[integer]: {callback: function, msg: {subject: string, reply_to?: string, payload: string}}}
---@operator call: nats.TestNats
local TestNats = class()

function TestNats:new()
	self.published = {}
	self.subscribers = {}
	self.pending = {}
end

--- Parse a NATS subject pattern into a matcher function.
--- Supports `*` (single token) and `>` (multi-token) wildcards.
---@param subject string
---@return nats.SubjectMatcher
local function parse_subject(subject)
	local parts = {}
	for token in subject:gmatch("[^%.]+") do
		table.insert(parts, token)
	end

	return function(actual)
		local actual_parts = {}
		for token in actual:gmatch("[^%.]+") do
			table.insert(actual_parts, token)
		end

		-- Handle `>` wildcard (matches rest of subject)
		local has_multi = false
		local multi_idx = 0
		for i, p in ipairs(parts) do
			if p == ">" then
				has_multi = true
				multi_idx = i
				break
			end
		end

		if has_multi then
			if #actual_parts < #parts - 1 then
				return false
			end
			for i = 1, multi_idx - 1 do
				if parts[i] ~= "*" and parts[i] ~= actual_parts[i] then
					return false
				end
			end
			return true
		end

		if #parts ~= #actual_parts then
			return false
		end
		for i = 1, #parts do
			if parts[i] ~= "*" and parts[i] ~= actual_parts[i] then
				return false
			end
		end
		return true
	end
end

---@param opts {subject: string, reply_to?: string, payload?: string}
---@return boolean?, string?
function TestNats:publish(opts)
	local msg = {
		subject = opts.subject,
		reply_to = opts.reply_to,
		payload = opts.payload,
	}
	table.insert(self.published, msg)

	-- Deliver to matching subscribers
	for _, sub in ipairs(self.subscribers) do
		if sub.match(msg.subject) then
			table.insert(self.pending, { callback = sub.callback, msg = msg })
		end
	end
	return true
end

---@param subject string
---@param cb fun(message: {subject: string, reply_to?: string, payload: string})
---@return boolean?, string?
function TestNats:subscribe(subject, cb)
	table.insert(self.subscribers, {
		subject = subject,
		callback = cb,
		match = parse_subject(subject),
	})
	return true
end

---@param subject string
---@return boolean?, string?
function TestNats:unsubscribe(subject)
	for i = #self.subscribers, 1, -1 do
		if self.subscribers[i].subject == subject then
			table.remove(self.subscribers, i)
		end
	end
	return true
end

--- Flush pending messages. Call after coroutine yield to simulate async delivery.
function TestNats:flush()
	for _, p in ipairs(self.pending) do
		p.callback(p.msg)
	end
	self.pending = {}
end

return TestNats
