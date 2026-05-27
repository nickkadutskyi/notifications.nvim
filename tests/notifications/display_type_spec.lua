-- tests/notifications/display_type_spec.lua
local DisplayType = require("notifications.notification_display_type")

describe("NotificationDisplayType", function()
    it("exports the expected keys", function()
        assert.are.equal("notification.type.no.popup", DisplayType.NONE)
        assert.are.equal("notification.type.balloon", DisplayType.BALLOON)
        assert.are.equal("notification.type.sticky.balloon", DisplayType.STICKY_BALLOON)
        assert.are.equal("notification.type.tool.window.balloon", DisplayType.TOOL_WINDOW_BALLOON)
    end)
end)
