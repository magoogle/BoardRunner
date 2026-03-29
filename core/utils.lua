-- ============================================================
--  BoardRunner - core/utils.lua
-- ============================================================

local utils = {}

local GEA_KUL_WP   = 0xB66AB
local GEA_KUL_ZONE = "Kehj_Gea_Kul"

function utils.in_gea_kul()
    local ok, zone = pcall(function()
        return get_current_world():get_current_zone_name()
    end)
    if not ok then return false end
    return zone and zone:find(GEA_KUL_ZONE) ~= nil
end

function utils.teleport_to_gea_kul()
    teleport_to_waypoint(GEA_KUL_WP)
end

function utils.distance_to(target)
    local player_pos = get_player_position()
    local target_pos
    if type(target) == "userdata" and target.get_position then
        target_pos = target:get_position()
    elseif type(target) == "userdata" then
        target_pos = target
    end
    if not target_pos then return 999 end
    return player_pos:dist_to(target_pos)
end

-- Find actor by exact or partial skin name match within range
function utils.find_actor(name_pattern, max_dist, exact)
    local actors = actors_manager:get_all_actors()
    local lp = get_local_player()
    if not lp then return nil end
    local pp = lp:get_position()
    local best, best_dist = nil, max_dist or 20.0
    for _, actor in pairs(actors) do
        local ok, name = pcall(function() return actor:get_skin_name() end)
        if ok and type(name) == "string" then
            local match = exact and (name == name_pattern)
                       or (not exact and name:find(name_pattern))
            if match then
                local d = pp:dist_to(actor:get_position())
                if d < best_dist then best = actor; best_dist = d end
            end
        end
    end
    return best
end

-- Count free inventory slots
function utils.free_inventory_slots()
    local lp = get_local_player()
    if not lp then return 0 end
    local ok, items = pcall(function() return lp:get_inventory_items() end)
    if not ok or type(items) ~= "table" then return 0 end
    -- D4 inventory is 35 slots total
    return math.max(0, 35 - #items)
end

-- Item quality helpers
function utils.get_item_quality(item)
    local ok, q = pcall(function() return item:get_item_quality() end)
    if not ok then return 0 end
    return q or 0
end

-- quality: 0=normal, 1=magic, 2=rare, 3=legendary/set, 4=unique/mythic
function utils.is_normal(item)   return utils.get_item_quality(item) == 0 end
function utils.is_magic(item)    return utils.get_item_quality(item) == 1 end
function utils.is_rare(item)     return utils.get_item_quality(item) == 2 end
function utils.is_legendary(item) return utils.get_item_quality(item) == 3 end
function utils.is_unique(item)   return utils.get_item_quality(item) >= 4 end

return utils
