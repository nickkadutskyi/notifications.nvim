---@class NotificationSettingsClass
---@field metatable NotificationSettings Metatable for NotificationSettings instances. Use with `getmetatable(obj) == NotificationSettings.metatable`.
local NotificationSettingsClass = {}

---@class NotificationSettings
---@field groupId string
---@field displayType NotificationDisplayType
local NotificationSettings = { class = NotificationSettingsClass }
NotificationSettings.__index = NotificationSettings

NotificationSettingsClass.metatable = NotificationSettings

---@param groupId string
---@param displayType NotificationDisplayType
---@return NotificationSettings
function NotificationSettingsClass:new(groupId, displayType)
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({
        groupId = groupId,
        displayType = displayType,
    }, NotificationSettings)

    return self
end

---@param displayType NotificationDisplayType
---@return NotificationSettings
function NotificationSettings:withDisplayType(displayType)
    self.displayType = displayType
    return self
end

---@param other NotificationSettings
---@return boolean
function NotificationSettings:__eq(other)
    if type(other) ~= "table" or getmetatable(other) ~= NotificationSettings then
        return false
    end

    return self.groupId == other:getGroupId() and self.displayType == other:getDisplayType()
end

---@return string
function NotificationSettings:getGroupId()
    return self.groupId
end

---@return NotificationDisplayType
function NotificationSettings:getDisplayType()
    return self.displayType
end

return NotificationSettingsClass
