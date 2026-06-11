local M = {}

---@param opts notifications.UserOpts User config
function M.setup(opts)
    opts = opts or {}
    assert(type(opts) == "table", "Expected options to be a table, got " .. type(opts))
    require("notifications.config"):withUserConfig(opts)
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
---@field title string|nil text shown in the first line of the notification balloon
---@field subtitle string|nil text shown in the first line of the notification balloon alongside the title
---@field group string|"default"|"default-sticky"|nil registered groups or default ones
---@field icon string|nil icon to replace defualt ones, use it for info or hint

--- Displays a notification to the user.
---@param msg string Content of the notification to show to the user.
---@param level vim.log.levels|nil One of the values from |vim.log.levels|.
---@param opts notifications.Options|nil Optional parameters. Unused by default.
---@diagnostic disable-next-line: unused-local
function M.notify(msg, level, opts)
    opts = opts or {}
    level = level or vim.log.levels.INFO
    assert(type(M.level_names[level]) == "string", "Invalid log level: " .. tostring(level))

    require("notifications.notification")
        .new(opts.group or "default", opts.title or "", msg or "", level)
        :setSubtitle(opts.subtitle)
        :setIcon(opts.icon)
        -- trigger notification
        :notify()
end

return M
