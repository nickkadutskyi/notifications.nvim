local utils = require("notifications.utils")
local conf = require("notifications.config")
local tab_manager = require("notifications.tab_manager")

local NotificationDisplayType = require("notifications.notification_display_type")
local Balloon = require("notifications.balloon")

---@class NotificationManagerClass
local NotificationManagerClass = {}

---@class NotificationManage
---@field private _isFocused boolean
---@field private _focusListeners fun()[]
local NotificationManager = { class = NotificationManagerClass }
NotificationManager.__index = NotificationManager

NotificationManagerClass.metatable = NotificationManager

--- CONSTRUCTOR ----------------------------------------------------------------

function NotificationManagerClass:new()
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({
        _isFocused = true,
        _focusListeners = {},
    }, NotificationManager)

    ---@diagnostic disable-next-line: invisible
    self:addFocusListeners()

    return self
end

--- STATIC METHODS -------------------------------------------------------------

--- INSTANCE METHODS -----------------------------------------------------------

---@private
function NotificationManager:addFocusListeners()
    local group = vim.api.nvim_create_augroup("notifications_focus_tracking", { clear = true })

    vim.api.nvim_create_autocmd("FocusGained", {
        group = group,
        callback = function()
            self._isFocused = true
            for _, listener in ipairs(self._focusListeners) do
                listener()
            end
            self._focusListeners = {}
        end,
    })

    vim.api.nvim_create_autocmd("FocusLost", {
        group = group,
        callback = function()
            self._isFocused = false
        end,
    })
end

---@param notification Notification
function NotificationManager:showNotification(notification)
    notification:assertHasTitleOrContent()

    local groupId = notification:getGroupId()
    local settings = conf:getSettings(groupId)
    local displayType = settings:getDisplayType()

    if not conf:isRegistered(groupId) then
        -- TODO: consider registering unknown groups
        notification:expire()
    end

    if not conf.SHOW_BALLOONS or displayType == NotificationDisplayType.NONE then
        notification:expire()
    end

    utils.invokeLater(function()
        self:doShowNotification(notification)
    end)
end

---@private
---@param notification Notification
---@return nil
function NotificationManager:doShowNotification(notification)
    ---@type string
    local groupId = notification:getGroupId()
    local settings = conf:getSettings(groupId)
    local displayType = settings:getDisplayType()

    if displayType == NotificationDisplayType.NONE then
        -- Do nothing TODO: maybe log if logging turned on
    elseif displayType == NotificationDisplayType.TOOL_WINDOW_BALLOON then
        -- Do nothing because not implemented TODO: maybe log if logging turned on
    elseif displayType == NotificationDisplayType.BALLOON or displayType == NotificationDisplayType.STICKY_BALLOON then
        local balloon = self:notifyByBalloon(notification, displayType)
        -- NOTE: Currently we alway expire notification when balloon closes
        --       but when we'll add tool bar with timeline (history) we will
        --       check whether the notification is logged into the timeline
        --       and will only expire it if it doesn't need to be in timeline
        -- if displayType == NotificationDisplayType.STICKY_BALLOON or true then
        if balloon == nil then
            notification:expire()
        else
            balloon:addListener({
                onClosed = function()
                    notification:expire()
                end,
            })
        end
        -- end
    end
end

---@private
---@param notification Notification
---@param displayType NotificationDisplayType
---@return Balloon|nil
function NotificationManager:notifyByBalloon(notification, displayType)
    local layout = tab_manager:getCurrentTabLayout()
    if layout == nil then
        return
    end

    local balloon = Balloon:new(notification)
    notification:setBalloon(balloon)

    if notification:isExpired() then
        return nil
    end

    layout:add(balloon)

    if balloon:isDisposed() then
        return nil
    end

    self:frameActivateBalloonListener(balloon, function()
        if not balloon:isDisposed() then
            local delay = displayType == NotificationDisplayType.STICKY_BALLOON and 300000 or 10000

            vim.defer_fn(function()
                if not balloon:isDisposed() then
                    balloon:hide()
                end
            end, delay)
        end
    end)

    -- Probably balloon will manage its rendering while layout will manage balloon's position
    return balloon
end

---@param balloon Balloon
---@param callback fun()
function NotificationManager:frameActivateBalloonListener(balloon, callback)
    if self._isFocused then
        callback()
    else
        table.insert(self._focusListeners, callback)

        -- Clear the callback if the balloon is closed before it ever triggers
        balloon:addListener({
            onClosed = function()
                for i, listener in ipairs(self._focusListeners) do
                    if listener == callback then
                        table.remove(self._focusListeners, i)
                        break
                    end
                end
            end,
        })
    end
end

local manager = NotificationManagerClass:new()
return manager
