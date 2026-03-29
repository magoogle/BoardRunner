-- ============================================================
--  BoardRunner - tasks/go_to_vendor.lua
--  Walks the returntovendor path to reach seller/salvager.
-- ============================================================

local settings   = require "core.settings"
local tracker    = require "core.tracker"
local utils      = require "core.utils"
local pathwalker = require "core.pathwalker"

local PATH = require "paths.to_vendor"

local STATE = { IDLE="IDLE", WALK="WALK" }
local s = { state=STATE.IDLE, t=-999 }
local function now()        return get_time_since_inject() end
local function set_state(x) s.state=x; s.t=now() end

local task = { name = "Go To Vendor" }

function task.shouldExecute()
if s.state ~= STATE.IDLE then return true end
if tracker.at_vendor then return false end
return tracker.loot_phase == "open_caches" or tracker.loot_phase == "sell" or tracker.loot_phase == "salvage"
end

function task.Execute()
    if s.state == STATE.IDLE then
        console.print("[BoardRunner] Walking to vendor area.")
        pathwalker.start(PATH, "to_vendor")
        set_state(STATE.WALK)
        return
    end

    if s.state == STATE.WALK then
        if pathwalker.is_done() or pathwalker.at_end() then
            console.print("[BoardRunner] Arrived at vendor area.")
            tracker.at_vendor = true
            tracker.at_board  = false
            pathwalker.stop()
            set_state(STATE.IDLE)
            return
        end
        pathwalker.update()
        return
    end
end

return task
