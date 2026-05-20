local NotificationGroup = require("notifications.notification_group")

---@class NotificationConfig
local NotificationConfig = {}
NotificationConfig.__index = NotificationConfig

function NotificationConfig:isRegistered()

end

---@param groupDisplayName string
---@param displayType NotificationDisplayType
function NotificationConfig:register(groupDisplayName, displayType)
    if not self:isRegistered(groupDisplayName) then
        NotificationGroup:new(groupDisplayName, displayType)
    end
end

return NotificationConfig
