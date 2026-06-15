---@class notifications.NotificationSettings
---@field groupId string
---@field displayType notifications.NotificationDisplayType
---@field isShouldLog boolean|nil
local NotificationSettings = {}
NotificationSettings.__index = NotificationSettings

---@param groupId string
---@param displayType notifications.NotificationDisplayType
---@param isShouldLog boolean|nil
function NotificationSettings.new(groupId, displayType, isShouldLog) ---@return notifications.NotificationSettings
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({
        groupId = groupId,
        displayType = displayType,
        isShouldLog = isShouldLog,
    }, NotificationSettings)

    return self
end

---@param displayType notifications.NotificationDisplayType
function NotificationSettings:withDisplayType(displayType) ---@return notifications.NotificationSettings
    self.displayType = displayType
    return self
end

---@param isShouldLog boolean
function NotificationSettings:withShouldLog(isShouldLog) ---@return notifications.NotificationSettings
    self.isShouldLog = isShouldLog
    return self
end

---@param other notifications.NotificationSettings
function NotificationSettings:__eq(other) ---@return boolean
    if type(other) ~= "table" or getmetatable(other) ~= NotificationSettings then
        return false
    end

    return self.groupId == other:getGroupId() and self.displayType == other:getDisplayType()
end

function NotificationSettings:getGroupId() ---@return string
    return self.groupId
end

function NotificationSettings:getDisplayType() ---@return notifications.NotificationDisplayType
    return self.displayType
end

function NotificationSettings:getShouldLog() ---@return boolean|nil
    return self.isShouldLog
end

return NotificationSettings
