-- ============================================================
--  BoardRunner - core/pathwalker.lua  (shared with Reaper)
--  Simplified copy — smooth lookahead walker.
-- ============================================================

local M = {}

M.is_walking             = false
M.current_path           = {}
M.original_path          = {}
M.current_waypoint_index = 1

local REACH_DIST      = 2.5
local LOOKAHEAD_DIST  = 8.0
local MOVE_INTERVAL   = 0.1
local STUCK_THRESHOLD = 3.0
local INTERACT_RANGE  = 3.5
local INTERACT_WAIT   = 2.5

local last_move_time  = 0
local last_pos        = nil
local last_pos_time   = 0
local stuck_timer     = 0
local interacting     = false
local interact_start  = 0

local function now() return get_gametime() end

local function normalise(points)
    local out = {}
    for _, p in ipairs(points) do
        if type(p) == "userdata" then
            out[#out+1] = { pos = p, action = nil }
        elseif type(p) == "table" then
            local pos
            if type(p[1]) == "userdata" then
                pos = p[1]
            else
                pos = vec3:new(p.x or p[1] or 0, p.y or p[2] or 0, p.z or p[3] or 0)
            end
            out[#out+1] = { pos = pos, action = p.action }
        end
    end
    return out
end

local function find_target_index(player_pos)
    local path = M.current_path
    local idx  = M.current_waypoint_index
    local n    = #path
    while idx <= n do
        if player_pos:dist_to_ignore_z(path[idx].pos) > REACH_DIST then break end
        idx = idx + 1
    end
    if idx > n then return n end
    if path[idx].action == "interact" then return idx end
    local best = idx
    for i = idx+1, n do
        if path[i].action == "interact" then break end
        if player_pos:dist_to_ignore_z(path[i].pos) <= LOOKAHEAD_DIST then
            best = i
        else break end
    end
    return best
end

local function try_interact(wp_pos)
    local player_pos = get_player_position()
    if not player_pos then return false end
    local actors = actors_manager:get_all_actors()
    local best, best_dist = nil, INTERACT_RANGE
    for _, actor in pairs(actors) do
        local ok, inter = pcall(function() return actor:is_interactable() end)
        if ok and inter then
            local d = player_pos:dist_to(actor:get_position())
            if d < best_dist then best = actor; best_dist = d end
        end
    end
    if best then
        interact_object(best)
        return true
    end
    return false
end

-- Find the closest waypoint index to the player's current position.
-- Used so that a path resumes from the nearest point instead of the start
-- when the plugin is reloaded mid-walk.
local function find_nearest_index(path)
    local pp = get_player_position()
    if not pp then return 1 end
    local best_idx, best_dist = 1, math.huge
    for i, wp in ipairs(path) do
        local d = pp:dist_to_ignore_z(wp.pos)
        if d < best_dist then
            best_idx  = i
            best_dist = d
        end
    end
    return best_idx
end

function M.start(points, name)
    if not points or #points == 0 then return false end
    M.current_path           = normalise(points)
    M.original_path          = M.current_path
    M.current_waypoint_index = find_nearest_index(M.current_path)
    M.is_walking             = true
    last_move_time           = 0
    last_pos                 = nil
    last_pos_time            = now()
    stuck_timer              = 0
    interacting              = false
    interact_start           = 0
    console.print(string.format("[BoardRunner] Walking: %s (%d pts, starting at %d)",
        name or "path", #M.current_path, M.current_waypoint_index))
    return true
end

function M.stop()
    M.is_walking             = false
    M.current_path           = {}
    M.original_path          = {}
    M.current_waypoint_index = 1
    interacting              = false
    last_pos                 = nil
end

function M.is_done()
    return not M.is_walking and #M.original_path > 0
end

function M.at_end()
    if not M.is_walking or #M.current_path == 0 then return false end
    local pp = get_player_position()
    if not pp then return false end
    return pp:dist_to_ignore_z(M.current_path[#M.current_path].pos) <= REACH_DIST
end

function M.update()
    if not M.is_walking or #M.current_path == 0 then return end
    local pp = get_player_position()
    if not pp then return end
    local n = #M.current_path
    local t = now()

    if interacting then
        if (t - interact_start) >= INTERACT_WAIT then
            interacting = false
            M.current_waypoint_index = math.min(M.current_waypoint_index + 1, n)
        else
            if (t - interact_start) > 0.5 then
                try_interact(M.current_path[M.current_waypoint_index].pos)
            end
        end
        return
    end

    if M.current_waypoint_index >= n then
        if pp:dist_to_ignore_z(M.current_path[n].pos) <= REACH_DIST then
            console.print("[BoardRunner] Path complete.")
            M.stop()
            return
        end
    end

    if last_pos then
        if pp:dist_to_ignore_z(last_pos) < 0.3 then
            stuck_timer = stuck_timer + (t - last_pos_time)
            if stuck_timer >= STUCK_THRESHOLD then
                M.current_waypoint_index = math.min(M.current_waypoint_index + 3, n)
                stuck_timer = 0
            end
        else
            stuck_timer = 0
        end
    end
    last_pos      = pp
    last_pos_time = t

    local target_idx = find_target_index(pp)
    M.current_waypoint_index = target_idx
    local wp = M.current_path[target_idx]

    if wp.action == "interact" then
        local dist = pp:dist_to_ignore_z(wp.pos)
        if dist <= INTERACT_RANGE then
            if try_interact(wp.pos) then
                interacting    = true
                interact_start = t
                return
            end
        end
        if (t - last_move_time) >= MOVE_INTERVAL then
            pathfinder.request_move(wp.pos)
            last_move_time = t
        end
        return
    end

    if (t - last_move_time) >= MOVE_INTERVAL then
        pathfinder.request_move(wp.pos)
        last_move_time = t
    end
end

return M
