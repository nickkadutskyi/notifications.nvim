---@class NotificationsBus
local NotificationsBus = {}

---@param notification Notification
function NotificationsBus.notify(notification)
    NotificationsBus.doNotify(notification)
end

---@param notification Notification
---@private
function NotificationsBus.doNotify(notification)
end

return NotificationsBus
