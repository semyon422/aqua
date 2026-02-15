local class = require("class")

---@class ui.IInputHandler
local IInputHandler = class()

---@param e ui.MouseDownEvent
function IInputHandler:onMouseDown(e) end

---@param e ui.MouseUpEvent
function IInputHandler:onMouseUp(e) end

---@param e ui.MouseClickEvent
function IInputHandler:onMouseClick(e) end

---@param e ui.ScrollEvent
function IInputHandler:onScroll(e) end

---@param e ui.DragStartEvent
function IInputHandler:onDragStart(e) end

---@param e ui.DragEvent
function IInputHandler:onDrag(e) end

---@param e ui.DragEndEvent
function IInputHandler:onDragEnd(e) end

---@param e ui.HoverEvent
function IInputHandler:onHover(e) end

---@param e ui.HoverLostEvent
function IInputHandler:onHoverLost(e) end

---@param e ui.FocusEvent
function IInputHandler:onFocus(e) end

---@param e ui.FocusLostEvent
function IInputHandler:onFocusLost(e) end

---@param e ui.KeyDownEvent
function IInputHandler:onKeyDown(e) end

---@param e ui.KeyUpEvent
function IInputHandler:onKeyUp(e) end

---@param e ui.TextInputEvent
function IInputHandler:onTextInput(e) end

return IInputHandler
