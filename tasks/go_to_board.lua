-- ============================================================
--  BoardRunner - tasks/go_to_board.lua
--  Teleports to Gea Kul then walks to the reward board.
-- ============================================================

local settings   = require "core.settings"
local tracker    = require "core.tracker"
local utils      = require "core.utils"
local pathwalker = require "core.pathwalker"

local PATH = require "paths.to_board"

local GEA_KUL_WP   = 0xB66AB
local ZONE_PATTERN  = "Kehj_Gea_Kul"

local STATE = { IDLE="IDLE", TELEPORT="TELEPORT", WAIT_ZONE="WAIT_ZONE", WALK="WALK" }
local s = { state=STATE.IDLE, t=-999 }
local function now()        return get_time_since_inject() end
local function set_state(x) s.state=x; s.t=now() end

local function in_zone()
    local ok, z = pcall(function() return get_current_world():get_current_zone_name() end)
    return ok and z and z:find(ZONE_PATTERN) ~= nil
end

local task = { name = "Go To Board" }

function task.shouldExecute()
if s.state ~= STATE.IDLE then return true end

-- Only go to board when we're in idle phase and we have inventory space to claim rewards.
if tracker.at_board then return false end
if tracker.at_vendor then return false end
if tracker.loot_phase ~= "idle" then return false end

local free = utils.free_inventory_slots()
if free <= 0 then
    -- Inventory full; go process caches/loot instead of claiming more.
    tracker.loot_phase = "open_caches"
    return false
end

return true
end

function task.Execute()
    if s.state == STATE.IDLE then
        if in_zone() then
            pathwalker.start(PATH, "to_board")
            set_state(STATE.WALK)
        else
            teleport_to_waypoint(GEA_KUL_WP)
            set_state(STATE.TELEPORT)
        end
        return
    end

    if s.state == STATE.TELEPORT then
        if (now() - s.t) >= 1.5 then set_state(STATE.WAIT_ZONE) end
        return
    end

    if s.state == STATE.WAIT_ZONE then
        if in_zone() then
            if (now() - s.t) >= 2.0 then
                pathwalker.start(PATH, "to_board")
                set_state(STATE.WALK)
            end
            return
        end
        if (now() - s.t) >= 20.0 then
            console.print("[BoardRunner] Zone timeout — retrying teleport.")
            teleport_to_waypoint(GEA_KUL_WP)
            set_state(STATE.TELEPORT)
        end
        return
    end

    if s.state == STATE.WALK then
        if pathwalker.is_done() or pathwalker.at_end() then
            console.print("[BoardRunner] Arrived at board.")
            tracker.at_board  = true
            tracker.at_vendor = false
            tracker.claims_this_visit = 0
            pathwalker.stop()
            set_state(STATE.IDLE)
            return
        end
        pathwalker.update()
        return
    end
end

return task
