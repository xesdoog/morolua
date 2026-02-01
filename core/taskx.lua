-- taskx.lua
-- Cooperative task scheduler built on coroutines

local taskx = {}

--tasks still need to be stored somewhere
--to make cancelling etc. stuff easy
--theyre stored locally here
local tasks = {}
-- Task object
local Task = {}
Task.__index = Task

-- create a new task object
function Task.new(fn)
    return setmetatable({
        co = coroutine.create(fn),
        wait = -1, --run immediatly on first update
        cancelled = false,
        paused = false
    }, Task)
end

-- cancel this task
function Task:cancel()
    self.cancelled = true
end

-- pause this task
function Task:pause()
    self.paused = true
end

-- resume this task
function Task:resume()
    self.paused = false
end

-- sleep from this task, equivalent of using taskx.sleep in the task thread
function Task:sleep(seconds)
    assert(
        coroutine.running() == self.co,
        "Task:sleep must be called from its own task"
    )
    coroutine.yield(seconds)
end


-- spawn a new task
function taskx.spawn(fn)
    local task = Task.new(fn)
    table.insert(tasks, task)
    return task
end

-- sleep inside a task
function taskx.sleep(seconds)
    assert(
        coroutine.running(),
        "taskx.sleep must be called inside a task"
    )
    coroutine.yield(seconds)
end

-- update all tasks (call every frame / tick)
function taskx.update(dt)
    for i = #tasks, 1, -1 do
        local task = tasks[i]

        if task.cancelled then
            table.remove(tasks, i)

        elseif not task.paused then
            task.wait = task.wait - dt

            if task.wait <= 0 then
                local ok, res = coroutine.resume(task.co)

                if not ok then
                    -- coroutine crashed, don't silently eat the error
                    print("[taskx] Task error:", res)
                    table.remove(tasks, i)

                elseif coroutine.status(task.co) == "dead" then
                    -- coroutine finished normally
                    table.remove(tasks, i)

                elseif type(res) == "number" then
                    task.wait = res
                end
            end
        end
    end
end



-- cancel all tasks
function taskx.cancelAll()
    for i = #tasks, 1, -1 do
    tasks[i] = nil
end
end

return taskx
