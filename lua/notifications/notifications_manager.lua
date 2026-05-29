local utils = require("notifications.utils")
local conf = require("notifications.config")
local NotificationDisplayType = require("notifications.notification_display_type")

local NotificationManagerClass = {}
local NotificationManager = {}
NotificationManager.__index = NotificationManager

function NotificationManagerClass:new()
    return setmetatable({}, NotificationManager)
end

---@param notification Notification
function NotificationManager:showNotification(notification)
    notification:assertHasTitleOrContent()

    if not conf:isRegistered(notification:getGroupId()) then
        return
    end

    if not conf.SHOW_BALLOONS then
        return
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
        self:notifyByBalloon(notification, displayType)
    end
end

---@private
---@param notification Notification
---@param displayType NotificationDisplayType
function NotificationManager:notifyByBalloon(notification, displayType) end

local manager = NotificationManagerClass:new()
return manager
