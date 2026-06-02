local utils = require("notifications.utils")

local Balloon = require("notifications.balloon")
local Notification = require("notifications.notification")

---@class BalloonLayoutClass
---@field public metatable BalloonLayout metatable for BalloonLayout instances. Use with `getmetatable(obj) == BalloonLayout.metatable`.
local BalloonLayoutClass = {}

---@class BalloonLayout
---@field private _visibleCount integer
---@field private _balloonWidth integer
---@field private _balloons Balloon[]
---@field private _collapsedBalloons Balloon[]
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
        _balloonWidth = 50,
        _balloons = {},
        _collapsedBalloons = {},
    }, BalloonLayout)
    return self
end

--- STATIC METHODS -------------------------------------------------------------

--- INSTANCE METHODS -----------------------------------------------------------

---@public
---@param newBalloon Balloon
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
---@param balloons Balloon[]
---@param startCol integer
---@param bottomRow integer
function BalloonLayout:_setBounds(balloons, startCol, bottomRow)
    local vertical_offset = 0
    local spacing = 1
    for _, balloon in ipairs(balloons) do
        ---@type BalloonBounds
        local bounds = {
            width = balloon:getWidth(),
            height = balloon:getHeight(),
        }
        bounds.col = startCol - bounds.width
        bounds.row = bottomRow - vertical_offset - bounds.height
        vertical_offset = vertical_offset + bounds.height + spacing
        -- local height = balloon:getHeight()
        -- local row = bottomRow - height + 1
        -- balloon:setPosition({ row = row, col = startCol })
        -- bottomRow = row - 1
        balloon:setBounds(bounds)
    end
end

---@private
---@param balloon Balloon
function BalloonLayout:_addNewBalloon(balloon)
    assert(type(balloon) == "table" and getmetatable(balloon) == Balloon.metatable, "Expected a Balloon instance")

    self._balloons[#self._balloons + 1] = balloon

    balloon:addListener({
        onClosed = function()
            self:_remove(balloon, false)
            utils.invokeLater(function()
                return self:_relayout()
            end)
        end,
    })

    self:_calculateSize()
    self:_relayout()

    if not balloon:isDisposed() then
        balloon:show()
    end

    -- Removing first and adding to the end if too many balloons are visible.
    -- if #self._balloons >= self._visibleCount then
    --     self:_remove(self._balloons[1])
    -- end

    -- TODO: do relayout instead of doing whatever I do now
    -- local width = self._balloonWidth
    -- balloon:setWidth(width)
    -- balloon:buildBuffer() -- required before getting height because of wrapping
    -- local height = balloon:getHeight()
    -- local bottom_margin = 2 + vim.o.cmdheight
    -- local right_margin = 3

    -- Position in bottom-right corner (simple version, no stacking)
    -- local row = vim.o.lines - height - bottom_margin
    -- local col = vim.o.columns - width - right_margin
    -- row = math.max(row, 0)
    -- col = math.max(col, 0)

    -- balloon:show()
end

---@private
---@param balloon Balloon
function BalloonLayout:_doCollapse(balloon) end

---@public
---@param balloonOrNotification Balloon|Notification
---@param hide boolean|nil
function BalloonLayout:_remove(balloonOrNotification, hide)
    ---@type Balloon|nil
    local balloon
    if type(balloonOrNotification) == "table" and getmetatable(balloonOrNotification) == Notification.metatable then
        -- it's a notification, try to get balloon from it
        balloon = balloonOrNotification:getBalloon()
        if balloon == nil then
            return
        end
    end
    if type(balloonOrNotification) == "table" and getmetatable(balloonOrNotification) == Balloon.metatable then
        balloon = balloonOrNotification --[[@as Balloon]]
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
