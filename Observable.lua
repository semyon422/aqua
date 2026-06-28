local class = require("class")
local table_util = require("table_util")

---@alias util.Observer {receive: fun(self: table, event: table)}
---@alias util.EventReceiver fun(event: table)

---@class util.Observable
---@operator call: util.Observable
local Observable = class()

---@param observer util.Observer|util.EventReceiver
---@return util.Observer
function Observable:add(observer)
	if type(observer) == "function" then
		---@cast observer util.EventReceiver
		local receive = observer
		observer = {
			receive = function(_, event)
				receive(event)
			end,
		}
	end
	---@cast observer util.Observer
	if not table_util.indexof(self, observer) then
		table.insert(self, observer)
	end
	return observer
end

---@generic T: util.Observer
---@param observer T
---@return T?
function Observable:remove(observer)
	local index = table_util.indexof(self, observer)
	if index then
		return table.remove(self, index)
	end
end

---@param event table
function Observable:send(event)
	if #self == 1 then
		self[1]:receive(event)
		return
	end

	for _, o in ipairs(table_util.copy(self) --[=[@as util.Observer[]]=]) do
		o:receive(event)
	end
end

Observable.receive = Observable.send

return Observable
