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

function BalloonLayout:add(balloon) end

-- --- FIXME: porbably should have a separate layout for each tabpage
-- ---        so that somewhere whenever I switch to a new tabpage it should
-- ---        check if layout is present for that tab and create it.
-- ---        This should allow to dispatch notifications into different tabs.
-- local layout = BalloonLayoutClass:new()
-- return layout

return BalloonLayoutClass
