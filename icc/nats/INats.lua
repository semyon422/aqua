local class = require("class")

---@class nats.INats
---@operator call: nats.INats
local INats = class()

---@param opts {subject: string, reply_to?: string, payload?: string}
---@return boolean?, string?
function INats:publish(opts) end

---@param subject string
---@param cb fun(message: {subject: string, reply_to?: string, payload: string})
---@return boolean?, string?
function INats:subscribe(subject, cb) end

---@param subject string
---@return boolean?, string?
function INats:unsubscribe(subject) end

return INats
