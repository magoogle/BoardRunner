-- ============================================================
--  BoardRunner - tasks/sell_loot.lua
--
--  Sells rares (and below if configured) to the Gea Kul vendor.
--  Uses loot_manager.sell_item — same as Alfred's approach.
-- ============================================================

local settings = require "core.settings"
local tracker  = require "core.tracker"
local utils    = require "core.utils"

local VENDOR_SKIN   = "TWN_Kehj_GeaKul_Vendor_Gambler"
local INTERACT_DIST = 4.0

local STATE = { IDLE="IDLE", WALK_TO="WALK_TO", OPEN="OPEN", SELLING="SELLING" }
local s = { state=STATE.IDLE, t=-999, last_sell=-999}
local SELL_INTERVAL  = 0.3
local OPEN_WAIT      = 1.0

local function now()        return get_time_since_inject() end
local function set_state(x) s.state=x; s.t=now() end

local function find_vendor()
    return utils.find_actor(VENDOR_SKIN, 20.0, true)
end

local function should_sell(item)
    if utils.is_unique(item)    then return false end  -- never sell uniques
    if utils.is_legendary(item) then return not settings.keep_legendaries end
    if utils.is_rare(item)      then return settings.sell_rares end
    return false  -- magic/normal handled by salvage
end

local function sell_all()
    local lp = get_local_player()
    if not lp then return 0 end
    local ok, items = pcall(function() return lp:get_inventory_items() end)
    if not ok or type(items) ~= "table" then return 0 end
    local count = 0
    for _, item in pairs(items) do
        if should_sell(item) then
            loot_manager.sell_item(item)
            count = count + 1
        end
    end
    return count
end

local task = { name = "Sell Loot" }

function task.shouldExecute()
    if s.state ~= STATE.IDLE then return true end
    return tracker.at_vendor and tracker.loot_phase == "sell"
end

function task.Execute()
    if s.state == STATE.IDLE then
        local vendor = find_vendor()
        if not vendor then
            console.print("[BoardRunner] Seller not found nearby.")
            set_state(STATE.IDLE)
            return
        end
        local dist = utils.distance_to(vendor)
        if dist > INTERACT_DIST then
            pathfinder.request_move(vendor:get_position())
            return
        end
        interact_vendor(vendor)
        console.print("[BoardRunner] Opened seller.")
        set_state(STATE.OPEN)
        return
    end

    if s.state == STATE.OPEN then
        if (now() - s.t) >= OPEN_WAIT then
            set_state(STATE.SELLING)
        end
        return
    end

    if s.state == STATE.SELLING then
        if (now() - s.last_sell) >= SELL_INTERVAL then
            local sold = sell_all()
            s.last_sell = now()
            if sold > 0 then
                console.print(string.format("[BoardRunner] Sold %d item(s).", sold))
            end
            utility.send_key_press(0x1B)  -- close vendor
            tracker.loot_phase = "salvage"
            set_state(STATE.IDLE)
        end
        return
    end
end

return task
