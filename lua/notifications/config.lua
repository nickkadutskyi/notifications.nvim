local group_manager = require("notifications.notification_group_manager")
local NotificationSettings = require("notifications.notification_settings")
local NotificationDisplayType = require("notifications.notification_display_type")

---@class NotificationsConfgiurationClass
---@field metatable NotificationsConfgiuration Metatable for NotificationsConfgiuration instances. Use with `getmetatable(obj) == NotificationsConfgiuration.metatable`.
local NotificationsConfgiurationClass = {}

---@class NotificationsConfgiuration
---@field public SHOW_BALLOONS boolean
---@field private _idToSettingsMap table<string, NotificationSettings>
local NotificationsConfgiuration = { class = NotificationsConfgiurationClass }
NotificationsConfgiuration.__index = NotificationsConfgiuration

NotificationsConfgiurationClass.metatable = NotificationsConfgiuration

---@return NotificationsConfgiuration
function NotificationsConfgiurationClass:new()
    return setmetatable({
        SHOW_BALLOONS = true,
        _idToSettingsMap = {},
    }, NotificationsConfgiuration)
end

---@public
---@param groupId string
---@return boolean
function NotificationsConfgiuration:isRegistered(groupId)
    return group_manager:isGroupRegistered(groupId)
end

---@public
---@param settings NotificationSettings
---@return nil
---@overload fun(self: NotificationsConfgiuration, groupId: string, displayType: NotificationDisplayType): nil
function NotificationsConfgiuration:changeSettings(settings, displayType)
    if type(settings) == "string" and type(displayType) == "string" then
        settings = NotificationSettings:new(settings, displayType)
    end
    assert(
        type(settings) == "table" and getmetatable(settings) == NotificationSettings.metatable,
        "Expected settings to be a NotificationSettings instance or (groupId, displayType)"
    )

    local groupDisplayName = settings:getGroupId()
    local defaultSettings = self:getDefaultSettings(groupDisplayName)
    if settings == defaultSettings then
        self._idToSettingsMap[groupDisplayName] = nil
    else
        self._idToSettingsMap[groupDisplayName] = settings
    end
end

---@class NotificationUserOpts
---@field display_balloon_notifications boolean|nil
---@field by_group table<string, {popup_type: NotificationDisplayType}>

---@param opts NotificationUserOpts
function NotificationsConfgiuration:withUserConfig(opts)
    for groupId, groupOpts in pairs(opts.by_group or {}) do
        local displayType = groupOpts.popup_type or NotificationDisplayType.BALLOON
        self:changeSettings(groupId, displayType)
    end

    self.SHOW_BALLOONS = opts.display_balloon_notifications ~= false
end

---@public
---@param groupId string
function NotificationsConfgiuration:getSettings(groupId)
    local settings = self._idToSettingsMap[groupId]

    return settings or self:getDefaultSettings(groupId)
end

---@private
---@param groupId string
---@return NotificationSettings
function NotificationsConfgiuration:getDefaultSettings(groupId)
    local group = group_manager:getNotificationGroup(groupId)
    if group ~= nil then
        return NotificationSettings:new(groupId, group:getDisplayType())
    end

    return NotificationSettings:new(groupId, NotificationDisplayType.BALLOON)
end

local config = NotificationsConfgiurationClass:new()
return config
