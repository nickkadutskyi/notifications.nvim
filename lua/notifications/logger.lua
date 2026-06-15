local uv = vim.uv or vim.loop

---@class notifications.Logger
---@field private _is_windows boolean
---@field private _is_mac boolean
---@field private _sep string
---@field private _log_file_path string|nil
---@field private _logfile file*|nil
---@field private _level vim.log.levels
local Logger = {}
Logger.__index = Logger

local LOG_FILE_MAX_SIZE = 5 * 1024 * 1024 -- 5 MB
local level_names = {
    [0] = "TRACE",
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "OFF",
}

--- CONSTRUCTORS ---------------------------------------------------------------

---@param level? vim.log.levels
function Logger.new(level) ---@return notifications.Logger
    local self = setmetatable({
        _is_wndows = uv.os_uname().version:match("Windows"),
        _is_mac = uv.os_uname().sysname == "Darwin",
        _level = level ~= nil and level or vim.log.levels.INFO,
    }, Logger)
    self._sep = self._is_windows and "\\" or "/"

    if level == nil then
        local env_level = os.getenv("LOGGER_LEVEL")
        if env_level then
            local n = tonumber(env_level)
            if n and n == math.floor(n) then
                self._level = n
            end
        end
    end

    -- Backup old log file if it exists
    local logpath = self:getLogFilePath()
    local stat = uv.fs_stat(logpath)
    if stat and stat.type == "file" and stat.size >= LOG_FILE_MAX_SIZE then
        local backup_path = logpath .. ".bak"
        uv.fs_unlink(backup_path) -- Remove old backup if it exists
        uv.fs_rename(logpath, backup_path)
    end

    local parent = vim.fs.dirname(logpath)
    vim.fn.mkdir(parent, "p")

    local logfile, openerr = io.open(logpath, "a+")
    if not logfile then
        local err_msg = string.format("Failed to open conform.nvim log file: %s", openerr)
        error(err_msg)
    else
        self._logfile = logfile
    end

    return self
end

--- INSTNACE METHODS -----------------------------------------------------------

function Logger:getLogFilePath() ---@return string
    if self._log_file_path then
        return self._log_file_path
    end

    local ok, logpath = pcall(vim.fn.stdpath, "log")
    local stdpath = ok and logpath or vim.fn.stdpath("cache")
    assert(type(stdpath) == "string")

    self._log_file_path = table.concat({ stdpath, "notifications.log" }, self._sep)

    return self._log_file_path
end

---@private
---@param line string
function Logger:_write(line) ---@return nil void
    if not self._logfile then
        return
    end

    self._logfile:write(line)
    self._logfile:write("\n")
    self._logfile:flush()
end

---@param level vim.log.levels
---@param msg string
---@param ... any[]
---@return string
function Logger:_format(level, msg, ...)
    local args = vim.F.pack_len(...)
    for i = 1, args.n do
        local v = args[i]
        if type(v) == "table" then
            args[i] = vim.inspect(v)
        elseif v == nil then
            args[i] = "nil"
        end
    end
    local ok, text = pcall(string.format, msg, vim.F.unpack_len(args))
    local timestr = vim.fn.strftime("%Y-%m-%d %H:%M:%S")
    if ok then
        local str_level = level_names[level]
        return string.format("[%s] %s: %s", timestr, str_level, text)
    else
        return string.format(
            "%s[ERROR] error formatting log line: '%s' args %s",
            timestr,
            vim.inspect(msg),
            vim.inspect(args)
        )
    end
end

---@param level vim.log.levels
---@param msg string
---@param ... any[]
function Logger:log(level, msg, ...) ---@return nil void
    if self._level <= level then
        local text = self:_format(level, msg, ...)
        self:_write(text)
    end
end

---@param msg string
---@param ... any[]
function Logger:trace(msg, ...) ---@return nil void
    self:log(vim.log.levels.TRACE, msg, ...)
end

---@param msg string
---@param ... any[]
function Logger:debug(msg, ...) ---@return nil void
    self:log(vim.log.levels.DEBUG, msg, ...)
end

---@param msg string
---@param ... any[]
function Logger:info(msg, ...) ---@return nil void
    self:log(vim.log.levels.INFO, msg, ...)
end

---@param msg string
---@param ... any[]
function Logger:warn(msg, ...) ---@return nil void
    self:log(vim.log.levels.WARN, msg, ...)
end

---@param msg string
---@param ... any[]
function Logger:error(msg, ...) ---@return nil void
    self:log(vim.log.levels.ERROR, msg, ...)
end

local logger = Logger.new()
return logger
