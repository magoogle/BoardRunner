-- ============================================================
--  BoardRunner - tasks/go_to_board.lua
--  Teleports to season town then walks to the reward board.
-- ============================================================

local settings      = require "core.settings"
local tracker       = require "core.tracker"
local utils         = require "core.utils"
local pathwalker    = require "core.pathwalker"
local season_config = require "core.season_config"

local PATH = require "paths.to_board"

local STATE = { IDLE="IDLE", TELEPORT="TELEPORT", WAIT_ZONE="WAIT_ZONE", WALK="WALK" }
local s = { state=STATE.IDLE, t=-999 }
local function now()        return get_time_since_inject() end
local function set_state(x) s.state=x; s.t=now() end

local task = { name = "Go To Board" }

function task.reset()
    s.state = STATE.IDLE
    s.t     = -999
    pathwalker.stop()
end

function task.shouldExecute()
    if s.state ~= STATE.IDLE then return true end

    if tracker.at_board then return false end
    if tracker.at_vendor then return false end
    if tracker.loot_phase ~= "idle" then return false end

    local free = utils.free_inventory_slots()
    if free <= 0 then
        tracker.loot_phase = "open_caches"
        return false
    end

    return true
end

function task.Execute()
    if s.state == STATE.IDLE then
        if utils.in_season_town() then
            pathwalker.start(PATH, "to_board")
            set_state(STATE.WALK)
        else
            utils.teleport_to_town()
            set_state(STATE.TELEPORT)
        end
        return
    end

    if s.state == STATE.TELEPORT then
        if (now() - s.t) >= 1.5 then set_state(STATE.WAIT_ZONE) end
        return
    end

    if s.state == STATE.WAIT_ZONE then
        if utils.in_season_town() then
            if (now() - s.t) >= 2.0 then
                pathwalker.start(PATH, "to_board")
                set_state(STATE.WALK)
            end
            return
        end
        if (now() - s.t) >= 20.0 then
            console.print("[BoardRunner] Zone timeout — retrying teleport.")
            utils.teleport_to_town()
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
