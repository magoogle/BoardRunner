-- ============================================================
--  BoardRunner - tasks/claim_rewards.lua
--
--  Finds the board actor, interacts with it, then clicks the
--  reward button X times where X = free inventory slots.
--  Stops when:
--    - no more free inventory slots
--    - board actor not found (no more rewards)
-- ============================================================

local settings      = require "core.settings"
local tracker       = require "core.tracker"
local utils         = require "core.utils"
local season_config = require "core.season_config"

local STATE = {
    IDLE        = "IDLE",
    WALK_TO     = "WALK_TO",
    OPEN_BOARD  = "OPEN_BOARD",
    CLAIMING    = "CLAIMING",
}

local s = {
    state         = STATE.IDLE,
    t             = -999,
    claims_target = 0,      -- how many we plan to claim this visit (= free slots at start)
    claim_count   = 0,
    last_click    = -999,
}

local CLICK_INTERVAL = 1.5  -- seconds between reward clicks
local OPEN_WAIT      = 1.0  -- wait after interact before clicking

local function now()        return get_time_since_inject() end
local function set_state(x) s.state=x; s.t=now() end

local function find_board()
    return utils.find_actor(season_config.board_actor, 15.0, false)
end

local function do_claim_click()
    local rx = settings.board_click_x
    local ry = settings.board_click_y
    local x  = math.floor(get_screen_width()  * rx)
    local y  = math.floor(get_screen_height() * ry)
    console.print(string.format("[BoardRunner] Claiming reward click (%d, %d)", x, y))
    utility.send_mouse_click(x, y)
end

local task = { name = "Claim Rewards" }

function task.shouldExecute()
    if s.state ~= STATE.IDLE then return true end
    if not tracker.at_board then return false end
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
        -- Determine how many caches to claim based on current free slots
        local free = utils.free_inventory_slots()
        s.claims_target = free
        s.claim_count   = 0
        console.print(string.format("[BoardRunner] Free inventory slots: %d — will claim %d cache(s).", free, free))

        local board = find_board()
        if not board then
            console.print("[BoardRunner] Board not found — no more rewards?")
            tracker.at_board = false
            set_state(STATE.IDLE)
            return
        end
        local dist = utils.distance_to(board)
        if dist > 3.0 then
            pathfinder.request_move(board:get_position())
            return
        end
        interact_vendor(board)
        console.print("[BoardRunner] Opened board.")
        set_state(STATE.OPEN_BOARD)
        return
    end

    if s.state == STATE.OPEN_BOARD then
        if (now() - s.t) >= OPEN_WAIT then
            set_state(STATE.CLAIMING)
        end
        return
    end

    if s.state == STATE.CLAIMING then
        -- Check if we've claimed enough or inventory is full
        local free = utils.free_inventory_slots()
        if free <= 0 or s.claim_count >= s.claims_target then
            console.print(string.format("[BoardRunner] Done claiming — claimed %d, free slots: %d.",
                s.claim_count, free))
            utility.send_key_press(0x1B)  -- close board UI
            tracker.loot_phase = "open_caches"
            set_state(STATE.IDLE)
            return
        end

        if (now() - s.last_click) >= CLICK_INTERVAL then
            do_claim_click()
            s.last_click = now()
            s.claim_count = s.claim_count + 1
            tracker.claims_this_visit = tracker.claims_this_visit + 1
            tracker.total_claims      = tracker.total_claims + 1
            console.print(string.format("[BoardRunner] Claimed %d / %d this visit (%d total)",
                s.claim_count, s.claims_target, tracker.total_claims))
        end
        return
    end
end

return task
