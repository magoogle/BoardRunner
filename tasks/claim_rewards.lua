-- ============================================================
--  BoardRunner - tasks/claim_rewards.lua
-- ============================================================

local tracker       = require "core.tracker"
local utils         = require "core.utils"
local season_config = require "core.season_config"

local STATE = {
    IDLE      = "IDLE",
    APPROACH  = "APPROACH",   -- walk up to the board
    BURST     = "BURST",      -- 3 interact attempts to open/register the board
    CLAIMING  = "CLAIMING",   -- repeated interacts until slots stop decreasing
    WALK_AWAY = "WALK_AWAY",
}

local s = {
    state           = STATE.IDLE,
    t               = -999,
    last_act        = -999,
    burst_count     = 0,
    claim_count     = 0,
    slots_before    = nil,
    no_change_count = 0,
}

local APPROACH_DIST   = 5.0   -- get within this many yards before interacting
local BURST_COUNT     = 3     -- rapid interacts on first approach
local BURST_INTERVAL  = 0.5
local CLAIM_INTERVAL  = 1.2
local MAX_STUCK       = 2
local WALK_AWAY_DIST  = 8.0
local WALK_AWAY_WAIT  = 2.5

local function now()        return get_time_since_inject() end
local function set_state(x) s.state = x; s.t = now() end

local function find_board()
    return utils.find_actor(season_config.board_actor, 20.0, false)
end

-- Try interact_vendor first (worked historically), fall back to interact_object
local function do_interact(board)
    local ok = interact_vendor(board)
    console.print(string.format("[BoardRunner] interact_vendor -> %s", tostring(ok)))
    if not ok then
        ok = interact_object(board)
        console.print(string.format("[BoardRunner] interact_object -> %s", tostring(ok)))
    end
    return ok
end

local function walk_away_from_board()
    local lp = get_local_player()
    if not lp then return end
    local pp = lp:get_position()
    local board = find_board()
    local dest = nil
    if board then
        pcall(function() dest = pp:get_extended(board:get_position(), WALK_AWAY_DIST) end)
    end
    if not dest then
        pcall(function() dest = vec3:new(pp:x() + WALK_AWAY_DIST, pp:y(), pp:z()) end)
    end
    if dest then pathfinder.request_move(dest) end
end

local task = { name = "Claim Rewards" }

function task.reset()
    s.state           = STATE.IDLE
    s.t               = -999
    s.last_act        = -999
    s.burst_count     = 0
    s.claim_count     = 0
    s.slots_before    = nil
    s.no_change_count = 0
end

function task.shouldExecute()
    if s.state ~= STATE.IDLE then return true end
    if not tracker.at_board then return false end
    if tracker.loot_phase ~= "idle" then return false end
    if utils.free_inventory_slots() <= 0 then
        tracker.loot_phase = "open_caches"
        return false
    end
    return true
end

function task.Execute()
    -- ----------------------------------------------------------------
    if s.state == STATE.IDLE then
        s.claim_count     = 0
        s.slots_before    = nil
        s.no_change_count = 0
        s.burst_count     = 0

        if utils.free_inventory_slots() <= 0 then
            console.print("[BoardRunner] No free slots — skipping to caches.")
            tracker.loot_phase = "open_caches"
            return
        end

        local board = find_board()
        if not board then
            console.print("[BoardRunner] Board actor not found.")
            tracker.at_board = false
            return
        end

        console.print(string.format("[BoardRunner] Board found (%.1f yds) — approaching.", utils.distance_to(board)))
        set_state(STATE.APPROACH)
        return
    end

    -- ----------------------------------------------------------------
    if s.state == STATE.APPROACH then
        local board = find_board()
        if not board then
            console.print("[BoardRunner] Board lost during approach.")
            set_state(STATE.IDLE)
            return
        end

        local dist = utils.distance_to(board)
        console.print(string.format("[BoardRunner] Approaching board... %.1f yds", dist))

        if dist <= APPROACH_DIST then
            console.print("[BoardRunner] In range — starting burst.")
            s.last_act = -999
            set_state(STATE.BURST)
            return
        end

        pathfinder.request_move(board:get_position())
        return
    end

    -- ----------------------------------------------------------------
    if s.state == STATE.BURST then
        if (now() - s.last_act) < BURST_INTERVAL then return end

        local board = find_board()
        if not board then
            console.print("[BoardRunner] Board lost during burst.")
            set_state(STATE.IDLE)
            return
        end

        local dist = utils.distance_to(board)
        if dist > APPROACH_DIST then
            pathfinder.request_move(board:get_position())
            return
        end

        s.burst_count = s.burst_count + 1
        console.print(string.format("[BoardRunner] Burst %d/%d (dist %.1f)", s.burst_count, BURST_COUNT, dist))
        do_interact(board)
        s.last_act = now()

        if s.burst_count >= BURST_COUNT then
            console.print("[BoardRunner] Burst done — entering claim loop.")
            s.slots_before    = nil
            s.no_change_count = 0
            s.last_act        = -999
            set_state(STATE.CLAIMING)
        end
        return
    end

    -- ----------------------------------------------------------------
    if s.state == STATE.CLAIMING then
        local free = utils.free_inventory_slots()

        if free <= 0 then
            console.print(string.format("[BoardRunner] Inventory full — claimed %d.", s.claim_count))
            tracker.loot_phase = "open_caches"
            set_state(STATE.IDLE)
            return
        end

        if (now() - s.last_act) < CLAIM_INTERVAL then return end

        -- Did the last interact reduce slots?
        if s.slots_before ~= nil then
            if free >= s.slots_before then
                s.no_change_count = s.no_change_count + 1
                console.print(string.format("[BoardRunner] No slot change (%d/%d).", s.no_change_count, MAX_STUCK))
                if s.no_change_count >= MAX_STUCK then
                    console.print("[BoardRunner] Stuck — walking away to retry.")
                    walk_away_from_board()
                    set_state(STATE.WALK_AWAY)
                    return
                end
            else
                s.no_change_count = 0
            end
        end

        local board = find_board()
        if not board then
            console.print("[BoardRunner] Board lost during claiming.")
            tracker.at_board = false
            set_state(STATE.IDLE)
            return
        end

        local dist = utils.distance_to(board)
        if dist > APPROACH_DIST then
            pathfinder.request_move(board:get_position())
            return
        end

        s.slots_before = free
        s.last_act     = now()
        s.claim_count  = s.claim_count + 1
        tracker.claims_this_visit = tracker.claims_this_visit + 1
        tracker.total_claims      = tracker.total_claims + 1

        console.print(string.format("[BoardRunner] Claim #%d (dist %.1f, %d free slots)", s.claim_count, dist, free))
        do_interact(board)
        return
    end

    -- ----------------------------------------------------------------
    if s.state == STATE.WALK_AWAY then
        if (now() - s.t) >= WALK_AWAY_WAIT then
            console.print("[BoardRunner] Retrying board after walk-away.")
            s.burst_count     = 0
            s.slots_before    = nil
            s.no_change_count = 0
            set_state(STATE.IDLE)
        else
            walk_away_from_board()
        end
        return
    end
end

return task
