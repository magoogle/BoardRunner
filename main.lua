-- ============================================================
--  BoardRunner  v1.1  by Magoogle
--
--  Opens Season Quest Board rewards, loots, sells/salvages,
--  and repeats until the board is empty or inventory is full.
--
--  Flow:
--    1. Teleport to Gea Kul
--    2. Walk to board
--    3. Click reward N times (configurable)
--    4. Walk to vendor area
--    5. Sell / salvage loot (Alfred-style)
--    6. Walk back to board
--    7. Repeat until done
-- ============================================================

local gui          = require "gui"
local task_manager = require "core.task_manager"
local settings     = require "core.settings"
local tracker      = require "core.tracker"

local enabled_last_frame = false
local enable_time        = 0
local startup_done       = false

local function on_enable()
    local lp = get_local_player()
    if not lp then return false end
    if (get_time_since_inject() - enable_time) < 0.5 then return false end

    console.print("=============================================")
    console.print("  BoardRunner  v1.1  by Magoogle  - STARTING")
    console.print("=============================================")

    settings:update_settings()
    tracker.reset()
    return true
end

local function on_disable()
    console.print("[BoardRunner] Stopped.")
    console.print(string.format("[BoardRunner] Total board claims this session: %d", tracker.total_claims))
end

on_update(function()
    settings:update_settings()
    local enabled = settings.enabled

    if enabled and not enabled_last_frame then
        enable_time        = get_time_since_inject()
        enabled_last_frame = true
        startup_done       = false
        return
    end

    if not enabled and enabled_last_frame then
        on_disable()
        enabled_last_frame = false
        startup_done       = false
        return
    end

    if not enabled then return end

    if not startup_done then
        local lp = get_local_player()
        if not lp or (get_time_since_inject() - enable_time) < 0.5 then return end
        startup_done = true
        local ok = on_enable()
        if not ok then
            gui.elements.main_toggle:set(false)
            enabled_last_frame = false
        end
        return
    end

    local lp = get_local_player()
    if not lp then return end

    task_manager.execute_tasks()
end)

on_render(function()
    gui.render_overlay()
end)

on_render_menu(gui.render)

console.print("=============================================")
console.print("  BoardRunner  v1.1  by Magoogle  - Loaded")
console.print("  Enable in menu to start")
console.print("=============================================")
