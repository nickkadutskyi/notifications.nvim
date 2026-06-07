local u = require("notifications.utils")

local NotificationBalloon = require("notifications.notification_balloon")
local Notification = require("notifications.notification")

---@class BalloonLayoutClass
---@field public metatable BalloonLayout metatable for BalloonLayout instances. Use with `getmetatable(obj) == BalloonLayout.metatable`.
local BalloonLayoutClass = {}

---@class BalloonLayout
---@field private _visibleCount integer
---@field private _balloonWidth integer
---@field private _balloons NotificationBalloon[]
---@field private _collapsedBalloons NotificationBalloon[]
local BalloonLayout = { class = BalloonLayoutClass }
BalloonLayout.__index = BalloonLayout

BalloonLayoutClass.metatable = BalloonLayout

--- CONSTRUCTORS ---------------------------------------------------------------

---@public
---@return BalloonLayout
function BalloonLayoutClass:new()
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({
        -- TODO: make it configurable
        _visibleCount = 3,
        _balloonWidth = 58,
        _balloons = {},
        _collapsedBalloons = {},
    }, BalloonLayout)
    return self
end

--- STATIC METHODS -------------------------------------------------------------

--- INSTANCE METHODS -----------------------------------------------------------

---@public
---@param newBalloon NotificationBalloon
function BalloonLayout:add(newBalloon)
    if #self._balloons < self._visibleCount then
        self:_addNewBalloon(newBalloon)
    else
        self:_doCollapse(newBalloon)
    end
end

---@private
function BalloonLayout:_calculateSize()
    for _, balloon in ipairs(self._balloons) do
        balloon:setWidth(self._balloonWidth)
        balloon:buildBuffer()
    end
end

---@private
function BalloonLayout:_relayout()
    local right_margin = 1
    local startCol = vim.o.columns - right_margin
    -- we are considering cmdheight config and expecting that statusline
    -- awlays takes 1 row
    local bottom_margin = 2 + vim.o.cmdheight
    local bottomRow = vim.o.lines - bottom_margin

    self:_setBounds(self._balloons, startCol, bottomRow)
end

---@private
---@param balloons NotificationBalloon[]
---@param startCol integer
---@param bottomRow integer
function BalloonLayout:_setBounds(balloons, startCol, bottomRow)
    local vertical_offset = 0
    local spacing = 1
    for _, balloon in ipairs(balloons) do
        ---@type BalloonBounds
        local bounds = {
            width = balloon:getWidth(),
            height = balloon:getHeight() or 1,
            col = startCol - balloon:getWidth(),
            row = bottomRow - vertical_offset - (balloon:getHeight() or 1),
        }
        vertical_offset = vertical_offset + bounds.height + spacing
        balloon:setBounds(bounds)
    end
end

---@private
---@param balloon NotificationBalloon
function BalloonLayout:_addNewBalloon(balloon)
    assert(u.is_a(balloon, NotificationBalloon), "Expected a Balloon instance")

    self._balloons[#self._balloons + 1] = balloon

    balloon:addListener({
        onClosed = function()
            self:_remove(balloon, false)
            u.invokeLater(function()
                return self:_relayout()
            end)
        end,
    })

    self:_calculateSize()
    self:_relayout()

    if not balloon:isDisposed() then
        balloon:show()
    end
end

---@private
---@param balloon NotificationBalloon
function BalloonLayout:_doCollapse(balloon) end

---@public
---@param balloonOrNotification NotificationBalloon|Notification
---@param hide boolean|nil
function BalloonLayout:_remove(balloonOrNotification, hide)
    ---@type NotificationBalloon|nil
    local balloon
    if u.is_a(balloonOrNotification, Notification.metatable) then
        -- it's a notification, try to get balloon from it
        balloon = balloonOrNotification:getBalloon()
        if balloon == nil then
            return
        end
    end
    if u.is_a(balloonOrNotification, NotificationBalloon) then
        balloon = balloonOrNotification --[[@as NotificationBalloon]]
        -- it's a balloon, do nothing
        for i, b in ipairs(self._balloons) do
            if b == balloon then
                table.remove(self._balloons, i)
                break
            end
        end
        if hide == true then
            balloon:hide()
        end
    end
end

return BalloonLayoutClass
