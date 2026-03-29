-- ============================================================
--  BoardRunner - core/task_manager.lua
-- ============================================================

local task_manager   = {}
local tasks          = {}
local current_task   = { name = "Idle" }
local last_call_time = 0.0

function task_manager.register_task(task)
    table.insert(tasks, task)
end

function task_manager.execute_tasks()
    local t = get_time_since_inject()
    if t - last_call_time < 0.1 then return end
    last_call_time = t

    for _, task in ipairs(tasks) do
        local ok, should = pcall(task.shouldExecute)
        if ok and should then
            current_task = task
            local ok2, err = pcall(task.Execute, task)
            if not ok2 then
                console.print("[BoardRunner] Task error in '" .. task.name .. "': " .. tostring(err))
            end
            return
        end
    end
    current_task = { name = "Idle" }
end

function task_manager.get_current_task()
    return current_task
end

local task_files = {
    "go_to_board",
    "claim_rewards",
    "go_to_vendor",       -- walk to vendor area first (needed before open/sell/salvage)
    "open_caches",
    "sell_loot",
    "salvage_loot",
    "return_to_board",
}

for _, f in ipairs(task_files) do
    local task = require("tasks." .. f)
    task_manager.register_task(task)
end

return task_manager
