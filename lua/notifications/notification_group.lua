---@class NotificationGroup
---@field id string
---@field displayType NotificationDisplayType
---@field title string|nil
---@field pluginId string|nil
local NotificationGroup = {}
NotificationGroup.__index = NotificationGroup

---@param id string
---@param displayType NotificationDisplayType
---@param title string|nil
---@param pluginId string|nil
function NotificationGroup.new(id, displayType, title, pluginId)
    return setmetatable({
        id = id,
        displayType = displayType,
        title = title or id,
        pluginId = pluginId,
    }, NotificationGroup)
end

---@return NotificationDisplayType
function NotificationGroup:getDisplayType()
    return self.displayType
end
---
---@return string
function NotificationGroup:__tostring()
    return string.format(
        "NotificationGroup{id='%s', displayType=%s, title='%s', pluginId='%s'}",
        self.id,
        self.displayType or "nil",
        self.title or "nil",
        self.pluginId or "nil"
    )
end

return NotificationGroup
