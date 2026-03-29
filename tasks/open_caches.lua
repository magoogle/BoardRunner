-- ============================================================
--  BoardRunner - tasks/open_caches.lua
--
--  Opens cache items in small batches so the resulting loot can
--  be sold/salvaged between batches (prevents inventory lockups).
--
--  Cache identification: item display/name contains "Cache"
--  Example: 'Greater Bloodied Cache {icon:AttributeBullet_GreaterAffix,1.5}'
-- ============================================================

local tracker  = require "core.tracker"

local STATE = { IDLE="IDLE", OPENING="OPENING" }
local s = { state=STATE.IDLE, last_open=-999, opened_in_batch=0 }

local OPEN_INTERVAL = 0.6
local BATCH_SIZE    = 5

local function now() return get_time_since_inject() end
local function set_state(x) s.state=x end

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
            caches[#caches+1] = item
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
    if s.state == STATE.IDLE then
        local caches = get_cache_items()
        if #caches == 0 then
            tracker.loot_phase = "sell"
            return
        end

        s.opened_in_batch = 0
        console.print(string.format("[BoardRunner] Opening up to %d cache(s) (found %d).", BATCH_SIZE, #caches))
        set_state(STATE.OPENING)
        return
    end

    if s.state == STATE.OPENING then
        if (now() - s.last_open) < OPEN_INTERVAL then return end

        if s.opened_in_batch >= BATCH_SIZE then
            console.print(string.format("[BoardRunner] Opened %d cache(s) this batch — processing loot.", s.opened_in_batch))
            tracker.loot_phase = "sell"
            set_state(STATE.IDLE)
            return
        end

        local caches = get_cache_items()
        if #caches == 0 then
            console.print("[BoardRunner] No more caches remaining.")
            tracker.loot_phase = "sell"
            set_state(STATE.IDLE)
            return
        end

        local item = caches[1]
        local label = item_label(item)
        local ok, err = open_cache(item)
        if ok then
            s.opened_in_batch = s.opened_in_batch + 1
            console.print(string.format("[BoardRunner] Opened cache: %s", tostring(label)))
        else
            console.print(string.format("[BoardRunner] Failed to open cache: %s (%s)", tostring(label), tostring(err)))
            tracker.loot_phase = "sell"
            set_state(STATE.IDLE)
            return
        end

        s.last_open = now()
        return
    end
end

return task
