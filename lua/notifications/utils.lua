local M = {}

--- Invoking
local invokationQueue = {}
local invokationScheduled = false
local invokationErrors = {}

local function reportErrors()
    if #invokationErrors == 0 then
        return
    end
    local errors = table.concat(invokationErrors, "\n")
    invokationErrors = {}
    -- TODO: log it somewhere since can't use vim.notify, maybe nvim_echo?
    -- vim.notify("Errors during notifications invokations:\n" .. errors, vim.log.levels.ERROR)
end
local function invoke()
    local timer, step_delay = assert(vim.loop.new_timer()), 1
    local fn
    fn = vim.schedule_wrap(function()
        local callback = invokationQueue[1]
        if callback == nil then
            invokationScheduled, invokationQueue = false, {}
            ---@diagnostic disable-next-line: need-check-nil
            timer:close()
            reportErrors()
            return
        end

        table.remove(invokationQueue, 1)
        M.invokeNow(callback)
        timer:start(step_delay, 0, fn)
    end)
    ---@diagnostic disable-next-line: need-check-nil
    timer:start(step_delay, 0, fn)
end

local function scheduleIvokations()
    if invokationScheduled then
        return
    end
    vim.schedule(invoke)
    invokationScheduled = true
end

---@param runnable function
function M.invokeLater(runnable)
    table.insert(invokationQueue, runnable)
    scheduleIvokations()
end

---@param runnable function
function M.invokeNow(runnable)
    local ok, err = pcall(runnable)
    if not ok then
        table.insert(invokationErrors, "now: " .. tostring(err))
    end
    scheduleIvokations()
end

---@param str string|any
---@return boolean
function M.isEmptyStr(str)
    return type(str) ~= "string" or str:match("^%s*$") ~= nil
end

return M
