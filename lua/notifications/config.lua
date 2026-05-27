local group_manager = require("notifications.notification_group_manager")

---@class NotificationsConfgiurationClass
local NotificationsConfgiurationClass = {}
---@class NotificationsConfgiuration
local NotificationsConfgiuration = {}
NotificationsConfgiuration.__index = NotificationsConfgiuration

function NotificationsConfgiurationClass:new()
    return setmetatable({}, NotificationsConfgiuration)
end

---@param groupId string
---@return boolean
function NotificationsConfgiuration:isRegistered(groupId)
    return group_manager:isGroupRegistered(groupId)
end

function NotificationsConfgiuration:register(displayName, displayType, displayTitle)
end

local config = NotificationsConfgiurationClass:new()
return config
