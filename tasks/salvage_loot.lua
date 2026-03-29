-- ============================================================
--  BoardRunner - tasks/salvage_loot.lua
--
--  Salvages magic/normal items at the Gea Kul blacksmith.
-- ============================================================

local settings = require "core.settings"
local tracker  = require "core.tracker"
local utils    = require "core.utils"

local SALVAGE_SKIN  = "TWN_Kehj_GeaKul_Crafter_Blacksmith"
local INTERACT_DIST = 4.0

local STATE = { IDLE="IDLE", WALK_TO="WALK_TO", OPEN="OPEN", SALVAGING="SALVAGING" }
local s = { state=STATE.IDLE, t=-999 }
local OPEN_WAIT = 1.0

local function now()        return get_time_since_inject() end
local function set_state(x) s.state=x; s.t=now() end


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

local function count_cache_items()
    local lp = get_local_player()
    if not lp then return 0 end
    local ok, items = pcall(function() return lp:get_inventory_items() end)
    if not ok or type(items) ~= "table" then return 0 end
    local n = 0
    for _, item in pairs(items) do
        if is_cache(item) then n = n + 1 end
    end
    return n
end


local function find_blacksmith()
    return utils.find_actor(SALVAGE_SKIN, 20.0, true)
end

local function should_salvage(item)
    if utils.is_unique(item)    then return false end
    if utils.is_legendary(item) then return false end  -- already sold or kept
    if utils.is_rare(item)      then return false end  -- already sold
    if utils.is_magic(item)     then return settings.salvage_magic end
    if utils.is_normal(item)    then return settings.salvage_normal end
    return false
end


local function try_salvage(item)
    if not loot_manager then return false, "loot_manager missing" end
    local candidates = {
        "salvage_item",
        "salvageItem",
        "salvage",
        "salvage_inventory_item",
        "salvageInventoryItem",
    }
    for _, fn in ipairs(candidates) do
        if type(loot_manager[fn]) == "function" then
            local ok, err = pcall(loot_manager[fn], item)
            if ok then return true end
            return false, err
        end
    end
    return false, "no salvage function available"
end

local function salvage_all()
    local lp = get_local_player()
    if not lp then return 0 end
    local ok, items = pcall(function() return lp:get_inventory_items() end)
    if not ok or type(items) ~= "table" then return 0 end
    local count = 0
    for _, item in pairs(items) do
        if should_salvage(item) then
            local ok = try_salvage(item)
            if ok then
                count = count + 1
            end
        end
    end
    return count
end

local task = { name = "Salvage Loot" }

function task.shouldExecute()
    if s.state ~= STATE.IDLE then return true end
    return tracker.at_vendor and tracker.loot_phase == "salvage"
end

function task.Execute()
    if s.state == STATE.IDLE then
        local bs = find_blacksmith()
        if not bs then
            console.print("[BoardRunner] Blacksmith not found nearby.")
            -- Skip salvage, proceed to return
            if count_cache_items() > 0 then
            tracker.loot_phase = "open_caches"
        else
            tracker.loot_phase = "done"
        end
            return
        end
        local dist = utils.distance_to(bs)
        if dist > INTERACT_DIST then
            pathfinder.request_move(bs:get_position())
            return
        end
        interact_vendor(bs)
        console.print("[BoardRunner] Opened blacksmith.")
        set_state(STATE.OPEN)
        return
    end

    if s.state == STATE.OPEN then
        if (now() - s.t) >= OPEN_WAIT then
            set_state(STATE.SALVAGING)
        end
        return
    end

    if s.state == STATE.SALVAGING then
        local salvaged = salvage_all()
        if salvaged > 0 then
            console.print(string.format("[BoardRunner] Salvaged %d item(s).", salvaged))
        end
        utility.send_key_press(0x1B)  -- close blacksmith
        if count_cache_items() > 0 then
            tracker.loot_phase = "open_caches"
        else
            tracker.loot_phase = "done"
        end
        set_state(STATE.IDLE)
        return
    end
end

return task
