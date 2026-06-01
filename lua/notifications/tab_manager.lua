local BalloonLayout = require("notifications.balloon_layout")

---@class TabManagerClass
---@field metatable TabManager metatable for TabManager instances. Use with `getmetatable(obj) == TabManager.metatable`.
local TabManagerClass = {}

---@class TabManager
---@field private _tabIdToLayout table<integer, BalloonLayout>
local TabManager = { class = TabManagerClass }
TabManager.__index = TabManager

TabManagerClass.metatable = TabManager

---@return TabManager
function TabManagerClass:new()
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({
        _tabIdToLayout = {},
    }, TabManager)

    local tab_id = vim.api.nvim_get_current_tabpage()
    ---@diagnostic disable-next-line: invisible
    self._tabIdToLayout[tab_id] = BalloonLayout:new()

    ---@diagnostic disable-next-line: invisible
    self:addTabpageListener()

    return self
end

---@private
function TabManager:addTabpageListener()
    local group = vim.api.nvim_create_augroup("TabManager", { clear = true })
    vim.api.nvim_create_autocmd("TabNewEntered", {
        group = group,
        callback = function()
            local tab_id = vim.api.nvim_get_current_tabpage()
            self._tabIdToLayout[tab_id] = BalloonLayout:new()
        end,
    })

    vim.api.nvim_create_autocmd("TabClosed", {
        group = group,
        callback = function()
            local tab_id = vim.api.nvim_get_current_tabpage()
            local layout = self._tabIdToLayout[tab_id]
            --- TODO: properly dispose the layout and its balloons
            self._tabIdToLayout[tab_id] = nil
        end,
    })
end

---@return BalloonLayout|nil
function TabManager:getCurrentTabLayout()
    local tab_id = vim.api.nvim_get_current_tabpage()
    return self._tabIdToLayout[tab_id]
end

local manager = TabManagerClass:new()
return manager
