local utils = require("utils")
local conf = require("notifications.config")

local NotificationManagerClass = {}
local NotificationManager = {}
NotificationManager.__index = NotificationManager

function NotificationManagerClass:new()
    return setmetatable({}, NotificationManager)
end

---@param notification Notification
function NotificationManager:showNotification(notification)
    notification:assertHasTitleOrContent()
    utils.invokeLater(function()
        self:doShowNotification(notification)
    end)
end

---@private
---@param notification Notification
function NotificationManager:doShowNotification(notification)
    if not conf:isRegistered(notification:getGroupId()) then
        -- TODO: register a new group
    end
end

local manager = NotificationManagerClass:new()
return manager
