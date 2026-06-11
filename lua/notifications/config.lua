local u = require("notifications.utils")

local NotificationSettings = require("notifications.notification_settings")
local NotificationDisplayType = require("notifications.notification_display_type")

---@class notifications.UserOpts
---@field display_balloon_notifications boolean|nil
---@field balloon_notifications_visible_count integer|nil
---@field by_group table<string, {popup_type: notifications.NotificationDisplayType}>

---@class notifications.Confgiuration
---@field public SHOW_BALLOONS boolean
---@field public BALLOONS_VISIBLE_COUNT integer
---@field private _idToSettingsMap table<string, notifications.NotificationSettings>
local Confgiuration = {}
Confgiuration.__index = Confgiuration

--- CONSTRUCTORS ---------------------------------------------------------------

function Confgiuration.new() ---@return notifications.Confgiuration
    return setmetatable({
        SHOW_BALLOONS = true,
        BALLOONS_VISIBLE_COUNT = 4,
        _idToSettingsMap = {},
    }, Confgiuration)
end

--- INSTANCE METHODS -----------------------------------------------------------

---@param groupId string
function Confgiuration:isRegistered(groupId) ---@return boolean
    return require("notifications.notification_group_manager"):isGroupRegistered(groupId)
end

---@param settings notifications.NotificationSettings
---@return nil
---@overload fun(self: notifications.Confgiuration, groupId: string, displayType: notifications.NotificationDisplayType): nil
function Confgiuration:changeSettings(settings, displayType)
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

---@param opts notifications.UserOpts
function Confgiuration:withUserConfig(opts) ---@return notifications.Confgiuration
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

    if opts.balloon_notifications_visible_count ~= nil then
        assert(
            type(opts.balloon_notifications_visible_count) == "number" and opts.balloon_notifications_visible_count > 0,
            "Expected balloon_notifications_visible_count to be a number, got "
                .. type(opts.balloon_notifications_visible_count)
                .. " with value more than 0."
        )
        self.BALLOONS_VISIBLE_COUNT = opts.balloon_notifications_visible_count
    end

    return self
end

---@public
---@param groupId string
function Confgiuration:getSettings(groupId) ---@return notifications.NotificationSettings
    local settings = self._idToSettingsMap[groupId]

    return settings or self:_getDefaultSettings(groupId)
end

---@private
---@param groupId string
function Confgiuration:_getDefaultSettings(groupId) ---@return notifications.NotificationSettings
    local group = require("notifications.notification_group_manager"):getNotificationGroup(groupId)
    if group ~= nil then
        return NotificationSettings.new(groupId, group:getDisplayType())
    end

    return NotificationSettings.new(groupId, NotificationDisplayType.BALLOON)
end

local config = Confgiuration.new()
return config
