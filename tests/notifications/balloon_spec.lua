-- tests/notifications/balloon_spec.lua
local Balloon = require("notifications.balloon")

describe("Balloon", function()
    it("recomputes border vertical padding when the border changes", function()
        local balloon = Balloon.new()

        balloon:setBorder("single")
        assert.are.equal(2, balloon:_getBorderVerticalPadding())

        balloon._border = "none"
        assert.are.equal(0, balloon:_getBorderVerticalPadding())
    end)

    it("caches border vertical padding until the border is set", function()
        local balloon = Balloon.new()
        local border = { "", "-", "", "", "", "-", "", "" }

        balloon:setBorder(border)
        assert.are.equal(2, balloon:_getBorderVerticalPadding())

        border[2] = ""
        border[6] = ""
        assert.are.equal(2, balloon:_getBorderVerticalPadding())

        balloon:setBorder(border)
        assert.are.equal(0, balloon:_getBorderVerticalPadding())
    end)
end)
