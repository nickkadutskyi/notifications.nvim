local utils = require("notifications.utils")

local NotificationDisplayType = require("notifications.notification_display_type")
local NotificationBalloon = require("notifications.notification_balloon")

---@class NotificationManager
---@field private _isFocused boolean
---@field private _focusListeners fun()[]
local NotificationManager = {}
NotificationManager.__index = NotificationManager

--- CONSTRUCTOR ----------------------------------------------------------------

function NotificationManager.new()
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({
        _isFocused = true,
        _focusListeners = {},
    }, NotificationManager)

    ---@diagnostic disable-next-line: invisible
    self:_addFocusListeners()

    return self
end

--- STATIC METHODS -------------------------------------------------------------

--- INSTANCE METHODS -----------------------------------------------------------

---@private
function NotificationManager:_addFocusListeners()
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

    local conf = require("notifications.config")

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
        self:_doShowNotification(notification)
    end)
end

---@private
---@param notification Notification
function NotificationManager:_doShowNotification(notification) ---@return nil void
    ---@type string
    local groupId = notification:getGroupId()
    local conf = require("notifications.config")
    local settings = conf:getSettings(groupId)
    local displayType = settings:getDisplayType()

    if displayType == NotificationDisplayType.NONE then
        -- Do nothing TODO: maybe log if logging turned on
    elseif displayType == NotificationDisplayType.TOOL_WINDOW_BALLOON then
        -- Do nothing because not implemented TODO: maybe log if logging turned on
    elseif displayType == NotificationDisplayType.BALLOON or displayType == NotificationDisplayType.STICKY_BALLOON then
        local balloon = self:_notifyByBalloon(notification, displayType)
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
function NotificationManager:_notifyByBalloon(notification, displayType) ---@return NotificationBalloon|nil
    local layout = require("notifications.tab_manager"):getCurrentTabLayout()
    if layout == nil then
        return
    end

    local balloon = NotificationBalloon.new(notification)
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

            local timer
            timer = vim.defer_fn(function()
                if not balloon:isDisposed() then
                    balloon:hideNowOrWhenCollapsed()
                end
            end, delay)

            -- Clear the timer if the balloon is closed before the delay
            balloon:addListener({
                onClosed = function()
                    if timer and not timer:is_closing() then
                        timer:stop()
                        timer:close()
                    end
                end,
            })
        end
    end)

    -- Probably balloon will manage its rendering while layout will manage balloon's position
    return balloon
end

---@param balloon NotificationBalloon
---@param callback fun()
function NotificationManager:frameActivateBalloonListener(balloon, callback) ---@return nil void
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

local manager = NotificationManager.new()
return manager
