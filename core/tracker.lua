-- ============================================================
--  BoardRunner - core/tracker.lua
-- ============================================================

local tracker = {
    total_claims    = 0,
    claims_this_visit = 0,
    at_board        = false,
    at_vendor       = false,
    loot_phase      = "idle",   -- idle / open_caches / sell / salvage / done
}

function tracker.reset()
    tracker.claims_this_visit = 0
    tracker.at_board          = false
    tracker.at_vendor         = false
    tracker.loot_phase        = "idle"
end

return tracker
