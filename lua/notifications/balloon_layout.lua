local u = require("notifications.utils")

local NotificationBalloon = require("notifications.notification_balloon")
local CollapseInfoBalloon = require("notifications.collapse_info_balloon")
local Notification = require("notifications.notification")

---@class BalloonLayout
---@field private _visibleCount integer
---@field private _balloonWidth integer
---@field private _balloons NotificationBalloon[]
---@field private _collapsedInfoBalloon CollapseInfoBalloon|nil
---@field private _queueRelayout DebouncedFunction
---@field private _isDisposed boolean
local BalloonLayout = {}
BalloonLayout.__index = BalloonLayout

local RELAYOUT_DEBOUNCE_MS = 50

--- CONSTRUCTORS ---------------------------------------------------------------

---@return BalloonLayout
function BalloonLayout.new()
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({
        -- TODO: make it configurable
        _visibleCount = 4,
        _balloonWidth = 56,
        _balloons = {},
        _collapsedInfoBalloon = nil,
        _isDisposed = false,
    }, BalloonLayout)

    self._queueRelayout = u.debounce(RELAYOUT_DEBOUNCE_MS, function()
        ---@diagnostic disable-next-line: invisible
        self:_calculateSize()
        ---@diagnostic disable-next-line: invisible
        self:_relayout()
    end)

    return self
end

--- STATIC METHODS -------------------------------------------------------------

--- INSTANCE METHODS -----------------------------------------------------------

---@param newBalloon NotificationBalloon
function BalloonLayout:add(newBalloon)
    if self._isDisposed then
        newBalloon:dispose()
        return
    end

    if #self._balloons < self._visibleCount then
        self:_addNewBalloon(newBalloon)
    else
        self:_doCollapse(newBalloon)
    end
end

function BalloonLayout:queueRelayout()
    if self._isDisposed then
        return
    end

    self._queueRelayout()
end

function BalloonLayout:dispose()
    if self._isDisposed then
        return
    end

    self._isDisposed = true
    self._queueRelayout.close()

    local balloons = self._balloons
    local collapsedInfoBalloon = self._collapsedInfoBalloon
    self._balloons = {}
    self._collapsedInfoBalloon = nil

    for _, balloon in ipairs(balloons) do
        balloon:dispose()
    end

    if collapsedInfoBalloon ~= nil then
        collapsedInfoBalloon:dispose()
    end
end

---@private
function BalloonLayout:_calculateSize()
    for _, balloon in ipairs(self._balloons) do
        balloon:setWidth(self._balloonWidth)
        balloon:buildBuffer()
    end
    if self._collapsedInfoBalloon then
        self._collapsedInfoBalloon:setWidth(self._balloonWidth)
        self._collapsedInfoBalloon:buildBuffer()
    end
end

---@private
function BalloonLayout:_relayout()
    local right_margin = 1
    local startCol = vim.o.columns - right_margin
    -- we are considering cmdheight config and expecting that statusline
    -- awlays takes 1 row
    local bottom_margin = 2 + vim.o.cmdheight

    local balloons = {}
    if self._collapsedInfoBalloon then
        table.insert(balloons, self._collapsedInfoBalloon)
        bottom_margin = bottom_margin - 1
    end

    local bottomRow = vim.o.lines - bottom_margin

    self:_setBounds(vim.list_extend(balloons, self._balloons), startCol, bottomRow)
end

---@private
---@param balloons NotificationBalloon[]
---@param startCol integer
---@param bottomRow integer
function BalloonLayout:_setBounds(balloons, startCol, bottomRow)
    local vertical_offset = 0
    local spacing = 1

    local extra_space = bottomRow
    for _, balloon in ipairs(balloons) do
        extra_space = extra_space - (math.min(balloon:getMaxHeight(), balloon:getHeight()) + spacing)
    end

    for _, balloon in ipairs(balloons) do
        local height
        if balloon:isCollapsed() then
            height = (balloon:getHeight() or 1)
        else
            height = (math.min(extra_space + balloon:getMaxHeight(), balloon:getHeight()) or 1)
        end
        ---@type BalloonBounds
        local bounds = {
            width = balloon:getWidth(),
            height = height,
            col = startCol - balloon:getWidth(),
            row = bottomRow - vertical_offset - height,
        }
        vertical_offset = vertical_offset + bounds.height + (u.is_a(balloon, CollapseInfoBalloon) and 0 or spacing)
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
            if #self._balloons == 0 and self._collapsedInfoBalloon then
                self._collapsedInfoBalloon:dispose()
            end
            self:queueRelayout()
        end,
        onContentUpdated = function()
            self:queueRelayout()
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
function BalloonLayout:_doCollapse(balloon)
    -- Select next balloon if the most oldest one is focused
    local oldBalloon = self._balloons[1]:isCollapsed() and self._balloons[1] or self._balloons[2]
    self:_remove(oldBalloon, true)
    if self._collapsedInfoBalloon == nil then
        self._collapsedInfoBalloon = CollapseInfoBalloon.new()
        self._collapsedInfoBalloon:addListener({
            onClosed = function()
                self._collapsedInfoBalloon = nil
                self:queueRelayout()
            end,
        })
    end
    self._collapsedInfoBalloon:increment()
    self:_addNewBalloon(balloon)
    self._collapsedInfoBalloon:show()
end

---@private
---@param balloonOrNotification NotificationBalloon|Notification
---@param hide boolean|nil
function BalloonLayout:_remove(balloonOrNotification, hide)
    ---@type NotificationBalloon|nil
    local balloon
    if u.is_a(balloonOrNotification, Notification) then
        balloon = balloonOrNotification:getBalloon()
        if balloon == nil then
            return
        end
    end
    if u.is_a(balloonOrNotification, NotificationBalloon) then
        balloon = balloonOrNotification --[[@as NotificationBalloon]]
        for i, b in ipairs(self._balloons) do
            if b == balloon then
                table.remove(self._balloons, i)
                break
            end
        end
        if hide == true then
            balloon:hideNowOrWhenCollapsed()
        end
    end
end

return BalloonLayout
