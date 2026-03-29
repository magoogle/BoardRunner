-- ============================================================
--  BoardRunner - tasks/open_caches.lua
--
--  Opens cache items in batches of 5, then waits for the
--  external loot plugin to pick up the drops. Monitors
--  inventory and transitions to sell/salvage when full.
--  Repeats until all caches are consumed.
-- ============================================================

local tracker = require "core.tracker"
local utils   = require "core.utils"

local STATE = {
    IDLE          = "IDLE",
    OPENING       = "OPENING",
    WAIT_LOOT     = "WAIT_LOOT",    -- pause for loot plugin to pick up drops
}

local s = {
    state           = STATE.IDLE,
    last_open       = -999,
    opened_in_batch = 0,
    wait_start      = 0,
}

local OPEN_INTERVAL  = 0.6   -- delay between opening individual caches
local BATCH_SIZE     = 5     -- open 5 caches per batch
local LOOT_WAIT      = 3.0   -- seconds to let loot plugin pick up items
local LOOT_CHECK_INT = 0.5   -- how often to re-check inventory during wait

local function now() return get_time_since_inject() end
local function set_state(x) s.state = x end

local function safe(fn)
    local ok, v = pcall(fn)
    return ok and v or nil
end

local function item_label(item)
    return safe(function() return item:get_display_name() end)
        or safe(function() return item:get_name() end)
        or tostring(item)
end

local function is_cache(item)
    local label = item_label(item)
    return type(label) == "string" and label:find("Cache") ~= nil
end

local function get_cache_items()
    local lp = get_local_player()
    if not lp then return {} end
    local ok, items = pcall(function() return lp:get_inventory_items() end)
    if not ok or type(items) ~= "table" then return {} end
    local caches = {}
    for _, item in pairs(items) do
        if is_cache(item) then
            caches[#caches + 1] = item
        end
    end
    return caches
end

local function open_cache(item)
    if loot_manager and type(loot_manager.use_item) == "function" then
        return pcall(loot_manager.use_item, item)
    end
    if loot_manager and type(loot_manager.consume_item) == "function" then
        return pcall(loot_manager.consume_item, item)
    end
    if loot_manager and type(loot_manager.open_item) == "function" then
        return pcall(loot_manager.open_item, item)
    end
    if loot_manager and type(loot_manager.activate_item) == "function" then
        return pcall(loot_manager.activate_item, item)
    end
    return false, "No loot_manager open/use method available"
end

local task = { name = "Open Caches" }

function task.shouldExecute()
    if s.state ~= STATE.IDLE then return true end
    return tracker.at_vendor and tracker.loot_phase == "open_caches"
end

function task.Execute()
    -- ----------------------------------------------------------------
    -- IDLE: check if there are caches to open; if not, move to sell
    -- ----------------------------------------------------------------
    if s.state == STATE.IDLE then
        local caches = get_cache_items()
        if #caches == 0 then
            console.print("[BoardRunner] No caches remaining — moving to sell phase.")
            tracker.loot_phase = "sell"
            return
        end

        s.opened_in_batch = 0
        console.print(string.format("[BoardRunner] Opening up to %d cache(s) (found %d).", BATCH_SIZE, #caches))
        set_state(STATE.OPENING)
        return
    end

    -- ----------------------------------------------------------------
    -- OPENING: open caches one at a time up to BATCH_SIZE (5)
    -- ----------------------------------------------------------------
    if s.state == STATE.OPENING then
        if (now() - s.last_open) < OPEN_INTERVAL then return end

        -- Batch complete → wait for loot plugin
        if s.opened_in_batch >= BATCH_SIZE then
            console.print(string.format("[BoardRunner] Opened %d cache(s) — waiting for loot plugin.", s.opened_in_batch))
            s.wait_start = now()
            set_state(STATE.WAIT_LOOT)
            return
        end

        local caches = get_cache_items()
        if #caches == 0 then
            console.print("[BoardRunner] All caches opened — waiting for loot plugin.")
            s.wait_start = now()
            set_state(STATE.WAIT_LOOT)
            return
        end

        local item  = caches[1]
        local label = item_label(item)
        local ok, err = open_cache(item)
        if ok then
            s.opened_in_batch = s.opened_in_batch + 1
            console.print(string.format("[BoardRunner] Opened cache: %s (%d/%d)",
                tostring(label), s.opened_in_batch, BATCH_SIZE))
        else
            console.print(string.format("[BoardRunner] Failed to open cache: %s (%s)", tostring(label), tostring(err)))
            tracker.loot_phase = "sell"
            set_state(STATE.IDLE)
            return
        end

        s.last_open = now()
        return
    end

    -- ----------------------------------------------------------------
    -- WAIT_LOOT: give the external loot plugin time to pick up drops,
    -- then check inventory. If full → sell/salvage; else open more.
    -- ----------------------------------------------------------------
    if s.state == STATE.WAIT_LOOT then
        local elapsed = now() - s.wait_start
        if elapsed < LOOT_WAIT then return end  -- still waiting

        local free   = utils.free_inventory_slots()
        local caches = get_cache_items()

        if free <= 0 then
            -- Inventory full — go sell/salvage before opening more
            console.print("[BoardRunner] Inventory full after opening caches — selling/salvaging.")
            tracker.loot_phase = "sell"
            set_state(STATE.IDLE)
            return
        end

        if #caches == 0 then
            -- All caches consumed — sell any remaining loot then return to board
            console.print("[BoardRunner] All caches opened and looted — moving to sell phase.")
            tracker.loot_phase = "sell"
            set_state(STATE.IDLE)
            return
        end

        -- More caches remain and we have space — open another batch
        console.print(string.format("[BoardRunner] %d cache(s) remain, %d free slots — opening next batch.",
            #caches, free))
        s.opened_in_batch = 0
        set_state(STATE.OPENING)
        return
    end
end

return task
