local Balloon = require("notifications.balloon")

---@class notifications.CollapseInfoBalloon: notifications.Balloon
---@field private _count integer
local CollapseInfoBalloon = {}
CollapseInfoBalloon.__index = CollapseInfoBalloon
setmetatable(CollapseInfoBalloon, Balloon)

--- CONSTRUCTORS ---------------------------------------------------------------

function CollapseInfoBalloon.new() ---@return notifications.CollapseInfoBalloon
    local self = setmetatable(Balloon.new(), CollapseInfoBalloon) --[[@as notifications.CollapseInfoBalloon]]
    self._statuscolumn = string.rep(" ", self._paddingX)
    self._count = 0
    self:setBorder({
        { "▕", "NotificationFloatBorderOuter" }, -- Top Left corner
        { "", "NotificationFloatBorderOuter" }, -- Title border
        { "▏", "NotificationFloatBorderOuter" }, -- Top Right corner
        { "▏", "NotificationFloatBorderOuter" },
        { " ", "NotificationFloatBorderOuter" },
        -- { "▁", "NotificationFloatBorderOuter" }, -- Footer border
        { "▔", "NotificationFloatBorderOuter" }, -- Footer border
        { " ", "NotificationFloatBorderOuter" },
        { "▕", "NotificationFloatBorderOuter" },
    })
    self._winhighlight = "Normal:NotificationFloatCollapseInfoNormal"
    self._height = 1
    self._maxContentHeight = 1
    return self
end

--- STATIC METHODS -------------------------------------------------------------

--- INSTANCE METHODS -----------------------------------------------------------

function CollapseInfoBalloon:increment()
    self._count = self._count + 1
    return self
end

function CollapseInfoBalloon:_doBuildContent()
    local lines = {} ---@type string[]
    local extramarks = {} ---@type {line:integer, col: integer, opts:vim.api.keyset.set_extmark}[]

    local info = self._count .. " more notifications"
    local info_width = vim.fn.strdisplaywidth(info)
    local left_padding = math.ceil((self._maxContentWidth - info_width) / 2)
    info = string.rep(" ", left_padding) .. info

    table.insert(lines, info)

    return { lines = lines, extramarks = extramarks }
end

return CollapseInfoBalloon
