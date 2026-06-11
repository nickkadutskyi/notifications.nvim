local level_names = {
    [0] = "TRACE",
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "OFF",
}

---@class notifications.Logger
local Logger = {}
Logger.__index = Logger

--- CONSTRUCTORS ---------------------------------------------------------------

function Logger.new() ---@return notifications.Logger
    local self = setmetatable({}, Logger)
    return self
end

--- INSTNACE METHODS -----------------------------------------------------------

local logger = Logger.new()
return logger
