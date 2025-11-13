---@class ui.Renderer.Ops
local t = {
	UPDATE_STYLE = 1,
	DRAW = 10,
	DRAW_STYLE_SHADOW = 11,
	DRAW_STYLE_BACKDROP = 12,
	DRAW_STYLE_CONTENT_ANY = 13,     -- node.draw and style.content
	DRAW_STYLE_CONTENT_TEXTURE = 14, -- style.content.texture
	DRAW_STYLE_CONTENT_NO_TEXTURE = 15, -- style.content
	STENCIL_START = 20,
	STENCIL_END = 21,
	CANVAS_START = 30,
	CANVAS_END = 31
}

return t
