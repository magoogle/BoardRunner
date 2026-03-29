-- ============================================================
--  BoardRunner - core/season_config.lua
--
--  *** SEASON-SPECIFIC VALUES ***
--  Update these each season. Only this file should need to
--  change when the board moves to a new town.
-- ============================================================

local season_config = {
    -- Town / zone
    town_name       = "Gea Kul",              -- display name (for logs)
    zone_pattern    = "Kehj_Gea_Kul",         -- substring matched against get_current_zone_name()
    waypoint_hash   = 0xB66AB,                -- teleport_to_waypoint() hash

    -- Season board actor
    board_actor     = "ReputationBoard",       -- skin-name pattern (partial match)

    -- Vendor / blacksmith actor skins (exact match)
    vendor_skin     = "TWN_Kehj_GeaKul_Vendor_Gambler",
    blacksmith_skin = "TWN_Kehj_GeaKul_Crafter_Blacksmith",
}

return season_config
