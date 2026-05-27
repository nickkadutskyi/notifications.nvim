---@class NotificationGroupClass
---@field private registeredGroups table<string, NotificationGroup>
local NotificationGroupClass = {
    registeredGroups = {},
}

---@class NotificationGroup
---@field displayId string
---@field displayType NotificationDisplayType
---@field title string|nil
---@field pluginId string|nil
local NotificationGroup = {}
NotificationGroup.__index = NotificationGroup

---@param displayId string
---@param displayType NotificationDisplayType
---@param title string|nil
---@param pluginId string|nil
function NotificationGroupClass:new(displayId, displayType, title, pluginId)
    return setmetatable({
        displayId = displayId,
        displayType = displayType,
        title = title or displayId,
        pluginId = pluginId,
    }, NotificationGroup)
end

return NotificationGroupClass
