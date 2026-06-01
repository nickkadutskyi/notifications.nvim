---@class BalloonLayoutClass
---@field public metatable BalloonLayout metatable for BalloonLayout instances. Use with `getmetatable(obj) == BalloonLayout.metatable`.
local BalloonLayoutClass = {}

---@class BalloonLayout
local BalloonLayout = { class = BalloonLayoutClass }
BalloonLayout.__index = BalloonLayout

BalloonLayoutClass.metatable = BalloonLayout

---@return BalloonLayout
function BalloonLayoutClass:new()
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({}, BalloonLayout)
    return self
end

---@param balloon Balloon
function BalloonLayout:add(balloon)
    if not balloon or not balloon.show then
        return
    end

    local width = 50
    local height = balloon.getHeight and balloon:getHeight() or 4
    local bottom_margin = 2 + vim.o.cmdheight + 2
    local right_margin = 3

    -- Position in bottom-right corner (simple version, no stacking)
    local row = vim.o.lines - height - bottom_margin
    local col = vim.o.columns - width - right_margin
    row = math.max(row, 0)
    col = math.max(col, 0)

    balloon:show(row, col)
end

-- --- FIXME: porbably should have a separate layout for each tabpage
-- ---        so that somewhere whenever I switch to a new tabpage it should
-- ---        check if layout is present for that tab and create it.
-- ---        This should allow to dispatch notifications into different tabs.
-- local layout = BalloonLayoutClass:new()
-- return layout

return BalloonLayoutClass
