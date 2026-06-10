local u = require("notifications.utils")

local NotificationSettings = require("notifications.notification_settings")
local NotificationDisplayType = require("notifications.notification_display_type")

---@class NotificationUserOpts
---@field display_balloon_notifications boolean|nil
---@field by_group table<string, {popup_type: NotificationDisplayType}>

---@class NotificationsConfgiuration
---@field public SHOW_BALLOONS boolean
---@field private _idToSettingsMap table<string, NotificationSettings>
local NotificationsConfgiuration = {}
NotificationsConfgiuration.__index = NotificationsConfgiuration

--- CONSTRUCTORS ---------------------------------------------------------------

function NotificationsConfgiuration.new() ---@return NotificationsConfgiuration
    return setmetatable({
        SHOW_BALLOONS = true,
        _idToSettingsMap = {},
    }, NotificationsConfgiuration)
end

--- INSTANCE METHODS -----------------------------------------------------------

---@param groupId string
function NotificationsConfgiuration:isRegistered(groupId) ---@return boolean
    return require("notifications.notification_group_manager"):isGroupRegistered(groupId)
end

---@param settings NotificationSettings
---@return nil
---@overload fun(self: NotificationsConfgiuration, groupId: string, displayType: NotificationDisplayType): nil
function NotificationsConfgiuration:changeSettings(settings, displayType)
    if type(settings) == "string" and type(displayType) == "string" then
        settings = NotificationSettings.new(settings, displayType)
    end
    assert(u.is_a(settings, NotificationSettings), "Expected settings to be a NotificationSettings instance")

    local groupDisplayName = settings:getGroupId()
    local defaultSettings = self:_getDefaultSettings(groupDisplayName)
    if settings == defaultSettings then
        self._idToSettingsMap[groupDisplayName] = nil
    else
        self._idToSettingsMap[groupDisplayName] = settings
    end
end

---@param opts NotificationUserOpts
function NotificationsConfgiuration:withUserConfig(opts) ---@return NotificationsConfgiuration
    if opts.by_group ~= nil and type(opts.by_group) == "table" then
        for groupId, groupOpts in pairs(opts.by_group or {}) do
            assert(type(groupId) == "string", "Expected groupId to be a string, got " .. type(groupId))
            assert(
                type(groupOpts) == "table",
                "Expected group options to be a table, got " .. type(groupOpts) .. " for groupId " .. groupId
            )
            local displayType = groupOpts.popup_type or NotificationDisplayType.BALLOON
            self:changeSettings(groupId, displayType)
        end
    end

    if opts.display_balloon_notifications ~= nil then
        self.SHOW_BALLOONS = opts.display_balloon_notifications ~= false
    end

    return self
end

---@public
---@param groupId string
function NotificationsConfgiuration:getSettings(groupId) ---@return NotificationSettings
    local settings = self._idToSettingsMap[groupId]

    return settings or self:_getDefaultSettings(groupId)
end

---@private
---@param groupId string
function NotificationsConfgiuration:_getDefaultSettings(groupId) ---@return NotificationSettings
    local group = require("notifications.notification_group_manager"):getNotificationGroup(groupId)
    if group ~= nil then
        return NotificationSettings.new(groupId, group:getDisplayType())
    end

    return NotificationSettings.new(groupId, NotificationDisplayType.BALLOON)
end

local config = NotificationsConfgiuration.new()
return config
