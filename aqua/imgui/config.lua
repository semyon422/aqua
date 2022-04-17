local imgui = require("cimgui")
local ffi = require("ffi")
local bit = require("bit")

local imio = imgui.GetIO()

local config = imgui.ImFontConfig()
config.FontDataOwnedByAtlas = false

local font_size = 20
local content, size = love.filesystem.read("resources/fonts/NotoSansCJK-Regular.ttc")
local newfont = imio.Fonts:AddFontFromMemoryTTF(ffi.cast("void*", content), size, font_size, config)
imio.FontDefault = newfont

imgui.love.BuildFontAtlas()

local Style = imgui.GetStyle()
Style.WindowRounding = 8
Style.FrameRounding = 4
Style.FramePadding.x = 7
Style.FramePadding.y = 7
Style.GrabRounding = 4

local Colors = Style.Colors
Colors[imgui.ImGuiCol_TitleBgActive]          = {0.21, 0.21, 0.21, 1.00}
Colors[imgui.ImGuiCol_Border]                 = {0.27, 0.27, 0.27, 1.00}

imio.ConfigFlags = bit.bor(imio.ConfigFlags, imgui.ImGuiConfigFlags_NavEnableKeyboard)
