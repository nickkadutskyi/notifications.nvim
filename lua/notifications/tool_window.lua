local Panel = require("notifications.panel")

local model = require("notifications.notifications_model")
local logger = require("notifications.logger")

---@class notifications.ToolWindow
---@field private _window? integer
---@field private _content? notifications.Panel
---@field private _isVisible boolean
---@field private _panel? notifications.Panel
---@field private _winclosed_autocmd? integer
local ToolWindow = {}
ToolWindow.__index = ToolWindow

--- FIXME this is unfinished, don't use it

--- CONSTRUCTORS ---------------------------------------------------------------

function ToolWindow.new() ---@return notifications.ToolWindow
    local self = setmetatable({
        _window = nil,
        _content = nil,
        _isVisible = false,
        _panel = nil,
        _winclosed_autocmd = nil,
    }, ToolWindow)
    return self
end

--- INSTANCE METHODS -----------------------------------------------------------

function ToolWindow:show() ---@return nil
    logger:debug("Showing the tool window.")

    if self:isVisible() then
        return
    end

    self:_createContentIfNeeded()

    if self._content then
        local buf = self._content:getBuffer()
        if buf ~= nil then
            self._isVisible = true
            self:_createWindow(buf):_configureWindow():_setupWinClosedAutocmd()
        end
    end

    -- self:_setupWinClosedAutocmd()
end

function ToolWindow:_createContentIfNeeded()
    if self._content ~= nil then
        return
    end

    local panel = Panel.new()
    panel:buildBuffer()
    model:register(panel)

    self._content = panel
end

function ToolWindow:isVisible() ---@return boolean
    return self._window ~= nil and vim.api.nvim_win_is_valid(self._window)
end

---@private
function ToolWindow:_getBounds() ---@return notifications.Bounds bounds
    local height = vim.o.lines - vim.o.cmdheight - 1
    local width = math.ceil(vim.o.columns * 0.2)
    local row = 0
    local col = vim.o.columns

    return {
        height = height,
        width = width,
        row = row,
        col = col,
    }
end

---@private
---@param buf integer
function ToolWindow:_createWindow(buf)
    local bounds = self:_getBounds()

    local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        width = bounds.width,
        height = bounds.height,
        row = bounds.row,
        col = bounds.col,
        style = "minimal",
        border = "rounded",
        zindex = 200,
        focusable = true,
    })

    self._window = win

    return self
end

---@private
function ToolWindow:_setupWinClosedAutocmd()
    if self._winclosed_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._winclosed_autocmd)
    end
    if self._window == nil or not vim.api.nvim_win_is_valid(self._window) then
        return
    end
    local win = self._window
    self._winclosed_autocmd = vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function()
            self._winclosed_autocmd = nil
            if self._window == win then
                self._window = nil
                self._isVisible = false
            end
        end,
    })

    return self
end

--- SINGLETON ------------------------------------------------------------------

---@private
function ToolWindow:_configureWindow()
    if self._window == nil or not vim.api.nvim_win_is_valid(self._window) then
        return self
    end
    local options = {
        signcolumn = "no",
        wrap = false,
        number = false,
        relativenumber = false,
        cursorline = true,
        winfixheight = false,
        list = false,
        foldenable = false,
        spell = false,
    }
    for name, value in pairs(options) do
        pcall(vim.api.nvim_set_option_value, name, value, { win = self._window })
    end

    return self
end

function ToolWindow:hide() ---@return nil
    if self._window ~= nil and vim.api.nvim_win_is_valid(self._window) then
        vim.api.nvim_win_close(self._window, true)
    end
    self._window = nil
end

function ToolWindow:toggle() ---@return nil
    if self:isVisible() then
        self:hide()
    else
        self:show()
    end
end

function ToolWindow:dispose() ---@return nil
    if self._winclosed_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._winclosed_autocmd)
        self._winclosed_autocmd = nil
    end

    if self._window ~= nil and vim.api.nvim_win_is_valid(self._window) then
        pcall(vim.api.nvim_win_close, self._window, true)
    end
    self._window = nil

    if self._panel ~= nil then
        pcall(function()
            local model = require("notifications.notifications_model")
            if model and type(model.unregister) == "function" then
                model:unregister(self._panel)
            end
        end)
        pcall(function()
            self._panel:dispose()
        end)
        self._panel = nil
    end
end

local window = ToolWindow
return window
