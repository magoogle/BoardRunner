-- ============================================================
--  BoardRunner - gui.lua  by Magoogle
-- ============================================================

local gui          = {}
local plugin_label = "BoardRunner"

local function cb(default, key)
    return checkbox:new(default, get_hash(plugin_label .. "_" .. key))
end
local function si(min, max, default, key)
    return slider_int:new(min, max, default, get_hash(plugin_label .. "_" .. key))
end
local function sf(min, max, default, key)
    return slider_float:new(min, max, default, get_hash(plugin_label .. "_" .. key))
end

gui.elements = {
    main_tree   = tree_node:new(0),
    main_toggle = cb(false, "enabled"),
    debug_interact = cb(false, "debug_interact"),  -- temp: fire board interact on demand

    -- Board click position (relative 0-1 for any resolution)
    align_tree      = tree_node:new(1),
    board_click_x   = sf(0.0, 1.0, 0.5,  "bcx"),
    board_click_y   = sf(0.0, 1.0, 0.4,  "bcy"),

    -- Loot handling
    loot_tree         = tree_node:new(3),
    sell_rares        = cb(true,  "sell_rares"),
    salvage_magic     = cb(true,  "salv_magic"),
    salvage_normal    = cb(true,  "salv_norm"),
    keep_legendaries  = cb(true,  "keep_leg"),
    keep_uniques      = cb(true,  "keep_uniq"),
}

function gui.render()
    if not gui.elements.main_tree:push("BoardRunner  v1.1  by Magoogle") then return end

    gui.elements.main_toggle:render("Enable", "Start / stop BoardRunner")
    gui.elements.debug_interact:render("[DEBUG] Test Board Interact", "Immediately tries interact_vendor + interact_object on the nearest board actor and prints results to console.")

    -- ---- Board Click Alignment ----
    if gui.elements.align_tree:push("Board Click Alignment") then
        gui.elements.board_click_x:render("Click X (0-1)",
            "Horizontal position of the reward claim button.\n0 = left edge, 1 = right edge.\nWorks at any resolution.", 2)
        gui.elements.board_click_y:render("Click Y (0-1)",
            "Vertical position of the reward claim button.\n0 = top, 1 = bottom.", 2)

        gui.elements.align_tree:pop()
    end

    -- ---- Loot Handling ----
    if gui.elements.loot_tree:push("Loot Handling") then
        gui.elements.keep_uniques:render("Keep Uniques / Mythics", "Never sell or salvage unique items.")
        gui.elements.keep_legendaries:render("Keep Legendaries", "Never sell or salvage legendary items.")
        gui.elements.sell_rares:render("Sell Rares", "Sell rare items to the vendor.")
        gui.elements.salvage_magic:render("Salvage Magic items", "Salvage magic (blue) items at the blacksmith.")
        gui.elements.salvage_normal:render("Salvage Normal items", "Salvage normal (white) items at the blacksmith.")
        gui.elements.loot_tree:pop()
    end

    gui.elements.main_tree:pop()
end

-- -------------------------------------------------------
-- Overlay: crosshair at the configured click position
-- -------------------------------------------------------
function gui.render_overlay()
    if not gui.elements.main_toggle:get() then return end

    local sw = get_screen_width()
    local sh = get_screen_height()
    local x  = math.floor(sw * gui.elements.board_click_x:get())
    local y  = math.floor(sh * gui.elements.board_click_y:get())

    local h = 16
    graphics.line(vec2:new(x-h, y), vec2:new(x+h, y), color_yellow(255), 2)
    graphics.line(vec2:new(x, y-h), vec2:new(x, y+h), color_yellow(255), 2)
    graphics.circle_2d(vec2:new(x, y), 5, color_yellow(255), 2)
    graphics.text_2d(
        string.format("Board Click  (%d, %d)", x, y),
        vec2:new(x+12, y-8), 11, color_yellow(255))
end

return gui
