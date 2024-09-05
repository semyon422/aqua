local class = require("class")

---@class web.UsecasePageContext
---@operator call: web.UsecasePageContext
---@field usecase_name string
---@field results table
---@field body_handler_name string?
---@field input_conv_name string?
---@field page_name string?
local UsecasePageContext = class()

---@param t table
function UsecasePageContext:new(t)
	self.usecase_name = t[1]
	self.results = t[2]
	self.body_handler_name = t[3]
	self.input_conv_name = t[4]
	self.page_name = t[5]
end

return UsecasePageContext
