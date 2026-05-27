---@enum NotificationDisplayType
local NotificationDisplayType = {
    NONE = "notification.type.no.popup",
    -- Expires automatically after 10 seconds.
    BALLOON = "notification.type.balloon",
    -- Needs to be closed by the user.
    STICKY_BALLOON = "notification.type.sticky.balloon",
    TOOL_WINDOW_BALLOON = "notification.type.tool.window.balloon",
}

return NotificationDisplayType
