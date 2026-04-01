-- ============================================================
--  BoardRunner - tasks/claim_rewards.lua
--
--  Finds the board actor, interacts with it, then clicks the
--  reward button. Re-checks free inventory slots EACH click
--  and stops as soon as inventory is full.
-- ============================================================

local settings      = require "core.settings"
local tracker       = require "core.tracker"
local utils         = require "core.utils"
local season_config = require "core.season_config"

local STATE = {
    IDLE        = "IDLE",
    OPEN_BOARD  = "OPEN_BOARD",
    CLAIMING    = "CLAIMING",
}

local s = {
    state         = STATE.IDLE,
    t             = -999,
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

function task.reset()
    s.state      = STATE.IDLE
    s.t          = -999
    s.claim_count = 0
    s.last_click = -999
end

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
        s.claim_count = 0

        -- Check free slots right now before we even open the board
        local free = utils.free_inventory_slots()
        if free <= 0 then
            console.print("[BoardRunner] No free inventory slots — skipping claims.")
            tracker.loot_phase = "open_caches"
            return
        end
        console.print(string.format("[BoardRunner] Free inventory slots: %d — opening board.", free))

        local board = find_board()
        if not board then
            console.print("[BoardRunner] Board not found — no more rewards?")
            tracker.at_board = false
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
        -- Re-check free slots EVERY tick — stop the moment inventory is full
        local free = utils.free_inventory_slots()
        if free <= 0 then
            console.print(string.format("[BoardRunner] Inventory full — claimed %d this visit.", s.claim_count))
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
            console.print(string.format("[BoardRunner] Claimed %d this visit, %d free slots remain (%d total)",
                s.claim_count, free - 1, tracker.total_claims))
        end
        return
    end
end

return task
