---@class notifications.NotificationGroup
---@field id string
---@field displayType notifications.NotificationDisplayType
---@field title string|nil
---@field pluginId string|nil
---@field isLogByDefault boolean
local NotificationGroup = {}
NotificationGroup.__index = NotificationGroup

---@param id string
---@param displayType notifications.NotificationDisplayType
---@param title string|nil
---@param pluginId string|nil
---@param isLogByDefault? boolean
function NotificationGroup.new(id, displayType, title, pluginId, isLogByDefault) ---@return notifications.NotificationGroup
    local self = setmetatable({
        id = id,
        displayType = displayType,
        title = title or id,
        pluginId = pluginId,
        isLogByDefault = isLogByDefault ~= nil and isLogByDefault or true,
    }, NotificationGroup)

    return self
end

function NotificationGroup:getDisplayType() ---@return notifications.NotificationDisplayType
    return self.displayType
end

function NotificationGroup:getShouldLogByDefault() ---@return boolean
    return self.isLogByDefault
end

---@return string
function NotificationGroup:__tostring()
    return string.format(
        "NotificationGroup{id='%s', displayType=%s, title='%s', pluginId='%s', isLogByDefault=%s}",
        self.id,
        self.displayType or "nil",
        self.title or "nil",
        self.pluginId or "nil",
        self.isLogByDefault and "true" or "false"
    )
end

return NotificationGroup
