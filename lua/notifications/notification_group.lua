---@class NotificationGroupClass
---@field metatable NotificationGroup Metatable for NotificationGroup instances. Use with `getmetatable(obj) == NotificationGroup.metatable`.
local NotificationGroupClass = {}

---@class NotificationGroup
---@field id string
---@field displayType NotificationDisplayType
---@field title string|nil
---@field pluginId string|nil
local NotificationGroup = { class = NotificationGroupClass }
NotificationGroup.__index = NotificationGroup

NotificationGroupClass.metatable = NotificationGroup

---@param id string
---@param displayType NotificationDisplayType
---@param title string|nil
---@param pluginId string|nil
function NotificationGroupClass:new(id, displayType, title, pluginId)
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

return NotificationGroupClass
