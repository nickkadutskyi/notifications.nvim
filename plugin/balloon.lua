---@class BalloonClass
---@field public metatable Balloon
local BalloonClass = {}

---@class Balloon
local Balloon = { class = BalloonClass }
Balloon.__index = Balloon

BalloonClass.metatable = Balloon

function BalloonClass:new()
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({}, Balloon)
    return self
end

return BalloonClass
