local ThreadRemote = require("threadremote.ThreadRemote")

local test = {}

---@class threadremote_test.Channel
---@field cleared boolean?
---@field clear fun(self: threadremote_test.Channel)
---@field push fun(self: threadremote_test.Channel, value: any)
---@field pop fun(self: threadremote_test.Channel): any?
---@field [integer] any

---@return threadremote_test.Channel
local function makeChannel()
	local channel = {}

	function channel:clear()
		for i = #self, 1, -1 do
			-- Test channels deliberately expose array slots and methods together.
			---@diagnostic disable-next-line: no-unknown
			self[i] = nil
		end
		self.cleared = true
	end

	function channel:push(value)
		-- Test channels deliberately expose array slots and methods together.
		---@diagnostic disable-next-line: no-unknown
		self[#self + 1] = value
	end

	function channel:pop()
		if #self == 0 then
			return nil
		end
		return table.remove(self, 1)
	end

	return channel
end

---@param f fun()
local function withFakeLove(f)
	local old_love = love
	---@type {[string]: threadremote_test.Channel}
	local channels = {}

	love = {
		thread = {
			getChannel = function(name)
				channels[name] = channels[name] or makeChannel()
				return channels[name]
			end,
			newThread = function()
				return {
					start = function() end,
					isRunning = function() return false end,
				}
			end,
		},
		filesystem = {
			read = function()
				return ""
			end,
		},
	}

	local ok, err = xpcall(f, debug.traceback)
	love = old_love
	if not ok then
		error(err)
	end
end

---@param t testing.T
function test.update_all_updates_active_remotes(t)
	withFakeLove(function()
		local remote = ThreadRemote("test", {})
		local updated = 0
		function remote.task_handler:update()
			updated = updated + 1
		end

		ThreadRemote.updateAll()

		t:eq(updated, 1)

		remote:stop()
	end)
end

---@param t testing.T
function test.stop_unregisters_remote(t)
	withFakeLove(function()
		local remote = ThreadRemote("test-stop", {})
		local input_channel = remote.input_channel
		local updated = 0
		function remote.task_handler:update()
			updated = updated + 1
		end

		remote:stop()
		ThreadRemote.updateAll()

		t:eq(updated, 0)
		t:eq(input_channel[#input_channel].name, "stop")
	end)
end

---@param t testing.T
function test.stop_detached_drops_pending_callbacks(t)
	withFakeLove(function()
		local remote = ThreadRemote("test-detached", {})
		local input_channel = remote.input_channel
		input_channel:push({name = "message"})
		local called = false
		remote.task_handler.callbacks[1] = function()
			called = true
		end
		remote.task_handler.timeouts[1] = 1

		remote:stopDetached()
		ThreadRemote.updateAll()

		t:eq(called, false)
		t:eq(remote.task_handler.callbacks[1], nil)
		t:eq(remote.task_handler.timeouts[1], nil)
		t:eq(#input_channel, 1)
		t:eq(input_channel[1].name, "stop")
	end)
end

return test
