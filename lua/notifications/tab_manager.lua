local BalloonLayout = require("notifications.balloon_layout")

---@class TabManager
---@field private _tabIdToLayout table<integer, BalloonLayout>
local TabManager = {}
TabManager.__index = TabManager

function TabManager.new() ---@return TabManager
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({
        _tabIdToLayout = {},
    }, TabManager)

    local tab_id = vim.api.nvim_get_current_tabpage()
    ---@diagnostic disable-next-line: invisible
    self._tabIdToLayout[tab_id] = BalloonLayout.new()

    ---@diagnostic disable-next-line: invisible
    self:_addTabpageListener()

    return self
end

---@private
function TabManager:_addTabpageListener() ---@return nil void
    local group = vim.api.nvim_create_augroup("TabManager", { clear = true })
    vim.api.nvim_create_autocmd("TabNewEntered", {
        group = group,
        callback = function()
            local tab_id = vim.api.nvim_get_current_tabpage()
            self._tabIdToLayout[tab_id] = BalloonLayout.new()
        end,
    })

    vim.api.nvim_create_autocmd("TabClosed", {
        group = group,
        callback = function(args)
            local tab_id = tonumber(args.file)
            if tab_id == nil then
                return
            end

            local layout = self._tabIdToLayout[tab_id]

            if layout ~= nil then
                layout:dispose()
            end

            self._tabIdToLayout[tab_id] = nil
        end,
    })
end

function TabManager:getCurrentTabLayout() ---@return BalloonLayout|nil
    local tab_id = vim.api.nvim_get_current_tabpage()
    return self._tabIdToLayout[tab_id]
end

local manager = TabManager.new()
return manager
