local u = require("notifications.utils")

local namespace = vim.api.nvim_create_namespace("notifications.panel")

---@class notifications.Panel: notifications.NotificationsModelListener
---@field private _buffer? integer
---@field private _isDisposed boolean
---@field private _namespace integer
---@field private _bufwipeout_autocmd? integer
local Panel = {}
Panel.__index = Panel

function Panel.new() ---@return notifications.Panel
    local self = setmetatable({
        _buffer = nil,
        _isDisposed = false,
        _namespace = namespace,
        _bufwipeout_autocmd = nil,
    }, Panel)
    return self
end

--- Get the buffer used for content. Creates one if needed.
function Panel:getBuffer() ---@return integer|nil
    if self._buffer ~= nil and vim.api.nvim_buf_is_valid(self._buffer) then
        return self._buffer
    end
    return nil
end

function Panel:buildBuffer() ---@return boolean
    return self:_createBuffer()
end

--- Create (or return existing) buffer for this panel.
--- ToolWindow will use this buffer to display in its window.
---@private
function Panel:_createBuffer() ---@return boolean
    if self._buffer ~= nil and vim.api.nvim_buf_is_valid(self._buffer) then
        return false
    end
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.bo[buffer].buftype = "nofile"
    vim.bo[buffer].bufhidden = "hide"
    vim.bo[buffer].modifiable = false
    vim.bo[buffer].filetype = "notifications"
    self._buffer = buffer
    self:_setupBufWipeoutAutocmd(buffer)
    self:_setupKeymaps(buffer)

    return true
end

--- Stub: refresh the buffer content from model.
--- Actual population logic is intentionally not implemented yet.
function Panel:refresh() ---@return nil
    if self._isDisposed then
        return
    end
    if self._buffer == nil or not vim.api.nvim_buf_is_valid(self._buffer) then
        return
    end
    -- STUB: do not fill buffer content yet
    -- In the future this will rebuild lines/extmarks from the model.
end

---@private
---@param buffer integer
function Panel:_setupBufWipeoutAutocmd(buffer) ---@return nil
    if self._bufwipeout_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._bufwipeout_autocmd)
    end
    if buffer == nil or not vim.api.nvim_buf_is_valid(buffer) then
        return
    end
    self._bufwipeout_autocmd = vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buffer,
        once = true,
        callback = function()
            self._bufwipeout_autocmd = nil
            if self._buffer == buffer then
                self._buffer = nil
            end
        end,
    })
end

---@private
---@param buffer integer
function Panel:_setupKeymaps(buffer) ---@return nil
    -- Minimal keymaps for the content buffer.
    -- "q" is a no-op here because the owning ToolWindow controls visibility.
    vim.keymap.set("n", "q", function()
        -- STUB: ToolWindow should handle closing. Panel only owns buffer.
    end, {
        buffer = buffer,
        nowait = true,
        silent = true,
        desc = "Close notifications panel (handled by ToolWindow)",
    })

    -- Stubs for content actions. Real implementation will use model + cursor mapping.
    vim.keymap.set("n", "dd", function()
        -- STUB: remove notification under cursor
    end, { buffer = buffer, nowait = true, silent = true, desc = "Remove notification (stub)" })

    vim.keymap.set("n", "C", function()
        -- STUB: clear all
        local model = require("notifications.notifications_model")
        if model and type(model.clearAll) == "function" then
            model:clearAll()
        end
    end, { buffer = buffer, nowait = true, silent = true, desc = "Clear all notifications (stub)" })
end

-- Model listener interface (stubs). ToolWindow/Manager will register us.

function Panel:add(_) ---@return nil
    u.invokeLater(function()
        self:refresh()
    end)
end

function Panel:remove(_) ---@return nil
    u.invokeLater(function()
        self:refresh()
    end)
end

function Panel:expireAll() ---@return nil
    u.invokeLater(function()
        self:refresh()
    end)
end

function Panel:clearAll() ---@return nil
    u.invokeLater(function()
        self:refresh()
    end)
end

function Panel:clearTimeline() ---@return nil
    u.invokeLater(function()
        self:refresh()
    end)
end

function Panel:clearUnreadStates() ---@return nil
    u.invokeLater(function()
        self:refresh()
    end)
end

function Panel:getNotifications() ---@return notifications.Notification[]
    local ok, model = pcall(require, "notifications.notifications_model")
    if ok and model and type(model.getNotifications) == "function" then
        return model:getNotifications()
    end
    return {}
end

function Panel:dispose() ---@return nil
    if self._isDisposed then
        return
    end
    self._isDisposed = true

    if self._bufwipeout_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._bufwipeout_autocmd)
        self._bufwipeout_autocmd = nil
    end

    local buf = self._buffer
    self._buffer = nil
    if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
end

return Panel
