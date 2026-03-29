-- ============================================================
--  BoardRunner - tasks/return_to_board.lua
--  Walks the to_vendor path in REVERSE back to the board.
--  Path reversal is deferred to Execute() to avoid crash
--  from calling vec3 methods at module load time.
-- ============================================================

local tracker    = require "core.tracker"
local pathwalker = require "core.pathwalker"

local STATE = { IDLE="IDLE", WALK="WALK" }
local s = { state=STATE.IDLE, t=-999 }
local function now()        return get_time_since_inject() end
local function set_state(x) s.state=x; s.t=now() end

local return_path_cache = nil

local function build_return_path()
    if return_path_cache then return return_path_cache end

    local VENDOR_PATH = require "paths.to_vendor"
    local out = {}
    for i = #VENDOR_PATH, 1, -1 do
        local p = VENDOR_PATH[i]
        if type(p) == "userdata" then
            -- plain vec3
            out[#out+1] = p
        elseif type(p) == "table" then
            -- { vec3, action="interact" } or plain {x,y,z} table
            -- On return trip strip interact actions — just walk
            local pos
            if type(p[1]) == "userdata" then
                pos = p[1]  -- reuse the vec3 directly
            else
                -- raw coordinate table
                local x = p.x or (type(p[1])=="number" and p[1]) or 0
                local y = p.y or (type(p[2])=="number" and p[2]) or 0
                local z = p.z or (type(p[3])=="number" and p[3]) or 0
                pos = vec3:new(x, y, z)
            end
            out[#out+1] = pos  -- strip action, plain walk only
        end
    end
    return_path_cache = out
    return out
end

local task = { name = "Return To Board" }

function task.shouldExecute()
    if s.state ~= STATE.IDLE then return true end
    return tracker.at_vendor and tracker.loot_phase == "done"
end

function task.Execute()
    if s.state == STATE.IDLE then
        console.print("[BoardRunner] Returning to board.")
        local path = build_return_path()
        pathwalker.start(path, "return_to_board")
        set_state(STATE.WALK)
        return
    end

    if s.state == STATE.WALK then
        if pathwalker.is_done() or pathwalker.at_end() then
            console.print("[BoardRunner] Back at board — ready for next claim.")
            tracker.at_vendor         = false
            tracker.at_board          = true
            tracker.loot_phase        = "idle"
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
