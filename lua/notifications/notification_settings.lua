---@class NotificationSettings
---@field groupId string
---@field displayType NotificationDisplayType
local NotificationSettings = {}
NotificationSettings.__index = NotificationSettings

---@param groupId string
---@param displayType NotificationDisplayType
---@return NotificationSettings
function NotificationSettings.new(groupId, displayType)
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

return NotificationSettings
