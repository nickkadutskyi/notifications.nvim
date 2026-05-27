-- tests/notifications/notification_group_spec.lua
local NotificationGroup = require("notifications.notification_group")
local DisplayType = require("notifications.notification_display_type")

describe("NotificationGroup", function()
    it("constructs with provided fields", function()
        local g = NotificationGroup:new("mygroup", DisplayType.BALLOON, "My Group", "my-plugin")

        assert.are.equal("mygroup", g.displayId)
        assert.are.equal(DisplayType.BALLOON, g.displayType)
        assert.are.equal("My Group", g.title)
        assert.are.equal("my-plugin", g.pluginId)
    end)

    it("accepts nil for optional fields", function()
        local g = NotificationGroup:new("id", DisplayType.STICKY_BALLOON)
        assert.are.equal("id", g.displayId)
        assert.is_nil(g.title)
        assert.is_nil(g.pluginId)
    end)
end)
