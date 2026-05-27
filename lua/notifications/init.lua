local NotificationGroupManager = require("notifications.notification_group_manager")

local M = {}

---@type NotificationGroupManager
M.notification_group_manager = nil

function M.setup()
    if M.notification_group_manager then
        return
    end
    M.notification_group_manager = NotificationGroupManager:new()
end

M.level_names = {
    [0] = "TRACE",
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "OFF",
}

---@class notifications.Options
---@field title string|nil
---@field type NotificationDisplayType|nil
---@field icon string|nil
---@field timeout number|boolean|nil Time to show notification in milliseconds, set to false to disable timeout.

--- Displays a notification to the user.
---@param msg string Content of the notification to show to the user.
---@param level vim.log.levels|nil One of the values from |vim.log.levels|.
---@param opts notifications.Options|nil Optional parameters. Unused by default.
---@diagnostic disable-next-line: unused-local
function M.notify(msg, level, opts)
    msg = msg or ""
    level = level or vim.log.levels.INFO
    assert(type(M.level_names[level]) == "string", "Invalid log level: " .. tostring(level))

    local n = require("notifications.notification"):new("main", opts and opts.title or "", msg, level)
    -- n.notify()
    -- vim.notify(n:getContent())
end

return M
