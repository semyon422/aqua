local ThreadRemote = require("threadremote.ThreadRemote")

local threadremote = {}

local lastId = 0

---@type {[integer]: threadremote.ThreadRemote}
local thread_remotes = {}

function threadremote.update()
	for _, thread_remote in pairs(thread_remotes) do
		thread_remote:update()
	end
end

function threadremote.remote(remote)
	lastId = lastId + 1
	local thread_remote = ThreadRemote(lastId, remote)
	return thread_remote.remote
end

return threadremote
