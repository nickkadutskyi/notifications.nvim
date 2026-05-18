local M = {}

function M.setup() end

---@enum notifications.Type
M.type = {
	BALLOON = 1,
	STICKY_BALLOON = 2,
	TOOL_WINDOW_BALLOON = 3,
	NO_POPUP = 4,
}

---@class notifications.Options
---@field title string|nil
---@field type notifications.Type|nil
---@field icon string|nil
---@field timeout number|boolean|nil Time to show notification in milliseconds, set to false to disable timeout.

--- Displays a notification to the user.
---
---@param msg string Content of the notification to show to the user.
---@param level vim.log.levels|nil One of the values from |vim.log.levels|.
---@param opts notifications.Options|nil Optional parameters. Unused by default.
---@diagnostic disable-next-line: unused-local
function M.notify(msg, level, opts) end

return M
