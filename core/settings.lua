-- ============================================================
--  BoardRunner - core/settings.lua
-- ============================================================

local gui      = require "gui"
local settings = {
    enabled          = false,
    sell_rares       = true,
    salvage_magic    = true,
    salvage_normal   = true,
    keep_legendaries = true,
    keep_uniques     = true,
    board_click_x    = 0.5,    -- relative 0-1
    board_click_y    = 0.4,
}

function settings:update_settings()
    settings.enabled          = gui.elements.main_toggle:get()
    settings.sell_rares       = gui.elements.sell_rares:get()
    settings.salvage_magic    = gui.elements.salvage_magic:get()
    settings.salvage_normal   = gui.elements.salvage_normal:get()
    settings.keep_legendaries = gui.elements.keep_legendaries:get()
    settings.keep_uniques     = gui.elements.keep_uniques:get()
    settings.board_click_x    = gui.elements.board_click_x:get()
    settings.board_click_y    = gui.elements.board_click_y:get()
end

return settings
