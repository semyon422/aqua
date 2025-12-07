---@class ui.Renderer.Ops
local t = {
	UPDATE_STYLE = 1,
	DRAW = 10,
	DRAW_STYLE_SHADOW = 11,
	DRAW_STYLE_BACKDROP = 12,
	DRAW_STYLE_CONTENT_SELF_DRAW = 13, -- node.draw and style.content
	DRAW_STYLE_CONTENT = 14,        -- style.content
	DRAW_STYLE_CONTENT_CACHE = 15,  -- style.cache
	STYLE_CONTENT_CACHE_BEGIN = 20,
	STYLE_CONTENT_CACHE_END = 21,
	STENCIL_START = 30,
	STENCIL_END = 31,
}

return t
