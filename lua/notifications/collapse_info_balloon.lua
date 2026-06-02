---@class CollapseInfoBalloonClass
---@field public metatable CollapseInfoBalloon metatable for CollapseInfoBalloon instances. Use with `getmetatable(obj) == CollapseInfoBalloon.metatable`.
local CollapseInfoBalloonClass = {}

---@class CollapseInfoBalloon
local CollapseInfoBalloon = { class = CollapseInfoBalloonClass }
CollapseInfoBalloon.__index = CollapseInfoBalloon

CollapseInfoBalloonClass.metatable = CollapseInfoBalloon

return CollapseInfoBalloonClass
