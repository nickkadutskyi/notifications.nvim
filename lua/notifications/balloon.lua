local namespace = vim.api.nvim_create_namespace("notifications.balloon")

---@class BalloonListener
---@field onClosed? fun(balloon: Balloon)
---@field onContentUpdated? fun(balloon: Balloon)

---@class BalloonBounds
---@field row integer
---@field col integer
---@field width integer
---@field height integer

---@class BalloonPosition
---@field row integer
---@field col integer

---@class BalloonContent
---@field lines string[]
---@field extramarks {line:integer, col: integer, opts:vim.api.keyset.set_extmark}[]

---@class Balloon
---@field protected _buffer? integer
---@field protected _window? integer
---@field protected _bounds? BalloonBounds
---@field protected _position? BalloonPosition
---@field protected _height? integer
---@field protected _maxContentWidth integer
---@field protected _maxContentHeight integer
---@field protected _paddingX integer
---@field protected _listeners BalloonListener[]
---@field protected _isDisposed boolean
---@field protected _statuscolumn string
---@field private _isVisible boolean
---@field private _border? any[]|"none"|"single"|"double"|"rounded"|"solid"|"shadow"
---@field protected _collapsed boolean
---@field private _winenter_autocmd? integer
---@field private _content? BalloonContent
local Balloon = {}
Balloon.__index = Balloon

--- CONSTRUCTORS ---------------------------------------------------------------

function Balloon.new() ---@return Balloon balloon
    local self = setmetatable({
        _buffer = nil,
        _window = nil,
        _position = nil,
        _bounds = nil,
        _height = nil,
        _maxContentWidth = 44,
        _maxContentHeight = 4,
        _paddingX = 4,
        _listeners = {},
        _isDisposed = false,
        _statuscolumn = "%!v:lua.require'notifications.balloon'.statuscolumn()",
        _isVisible = false,
        _border = {
            { "▕", "NotificationFloatBorderOuter" }, -- Top Left corner
            { "▔", "NotificationFloatBorder" }, -- Title border
            { "▏", "NotificationFloatBorderOuter" }, -- Top Right corner
            { "▏", "NotificationFloatBorderOuter" },
            { "▏", "NotificationFloatBorderOuter" },
            { "▁", "NotificationFloatBorder" }, -- Footer border
            { "▕", "NotificationFloatBorderOuter" },
            { "▕", "NotificationFloatBorderOuter" },
        },
        _collapsed = true,
    } --[[@as Balloon]], Balloon)
    return self
end

--- STATIC METHODS -------------------------------------------------------------

---@public
function Balloon.statuscolumn()
    return ""
end

--- INSTANCE METHODS -----------------------------------------------------------

function Balloon:isVisible() ---@return boolean
    return self._isVisible
end

---@param height integer
function Balloon:setMaxHeight(height) ---@return Balloon balloon
    self._maxContentHeight = height - self:_getBorderVerticalPadding()
    return self
end

function Balloon:getHeight() ---@return integer|nil
    return self._height ~= nil and (self._height + self:_getBorderVerticalPadding()) or nil
end

---@param width integer
function Balloon:setWidth(width) ---@return Balloon balloon
    self._maxContentWidth = width
        -- subtracting right padding
        - self._paddingX
        -- subtracting left padding
        - math.max(self._paddingX, 2)
        -- subtracting borders
        - 2
    return self
end

function Balloon:getWidth() ---@return integer
    return self._maxContentWidth
        -- right padding
        + self._paddingX
        -- left padding will always be at least 2 characters because of the icon
        + math.max(2, self._paddingX)
        -- adding 2 for the border
        + 2
end

---@param bounds BalloonBounds
function Balloon:setBounds(bounds) ---@return Balloon balloon
    self._bounds = bounds
    self:setWidth(bounds.width)
    self:_updatePosition(bounds)
    return self
end

---@private
---@param bounds BalloonBounds
function Balloon:_updatePosition(bounds) ---@return nil void
    self._position = {
        row = bounds.row,
        col = bounds.col,
    }

    -- Update window position if the window is already open
    if self._window == nil or self._position == nil then
        return
    end

    vim.api.nvim_win_set_config(self._window, {
        relative = "editor",
        row = self._position.row,
        col = self._position.col,
        height = self._height,
    })
end

function Balloon:hide() ---@return nil void
    self:dispose()
end

function Balloon:dispose() ---@return nil void
    if self._isDisposed then
        return
    end

    self._isDisposed = true

    if self._winenter_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._winenter_autocmd)
        self._winenter_autocmd = nil
    end

    for _, listener in ipairs(self._listeners) do
        if type(listener.onClosed) == "function" then
            listener.onClosed(self)
        end
    end

    if self._window ~= nil and vim.api.nvim_win_is_valid(self._window) then
        vim.api.nvim_win_close(self._window, true)
        self._window = nil
    end

    if self._buffer ~= nil and vim.api.nvim_buf_is_valid(self._buffer) then
        vim.api.nvim_buf_delete(self._buffer, { force = true })
        self._buffer = nil
    end
end

function Balloon:isDisposed() ---@return boolean
    return self._isDisposed
end

---@param listener BalloonListener
function Balloon:addListener(listener) ---@return nil void
    table.insert(self._listeners, listener)
end

---@param bounds BalloonBounds|nil
function Balloon:show(bounds)
    assert(self._isDisposed == false, "Balloon is already disposed")

    if self:isVisible() then
        return
    end

    self._isVisible = true

    if bounds ~= nil then
        self:setBounds(bounds)
    end

    self:_createBuffer()

    self._window = vim.api.nvim_open_win(self._buffer, false, {
        relative = "editor",
        -- detracting borders
        width = self:getWidth() - 2,
        height = self._height,
        row = self._position.row,
        col = self._position.col,
        style = "",
        border = self._border,
        zindex = 50,
        -- It should be focusable so we can copy the content, uncover full content (if collapsed), close
        focusable = true,
    })

    self:_configureWindow()
    self:_setWindowVariables()
    self:_setupWinEnterAutocmd()
end

---@private
function Balloon:_configureWindow()
    if self._window == nil or not vim.api.nvim_win_is_valid(self._window) then
        return
    end

    local options = {
        signcolumn = "no",
        wrap = false,
        linebreak = false,
        breakindent = false,
        breakindentopt = "",
        scrolloff = 0,
        sidescrolloff = 0,
        cursorline = false,
        number = false,
        relativenumber = false,
        statuscolumn = self._statuscolumn,
        spell = false,
        list = false,
        listchars = "",
        showbreak = "",
        winhighlight = "Normal:NotificationFloatNormal",
    }

    for name, value in pairs(options) do
        pcall(vim.api.nvim_set_option_value, name, value, { win = self._window })
    end
end

---@private
function Balloon:_setWindowVariables() ---@return nil void
    if self._window == nil or not vim.api.nvim_win_is_valid(self._window) then
        return
    end

    vim.w[self._window].balloon_padding = self._paddingX
end

---@private
function Balloon:_setupWinEnterAutocmd()
    if self._winenter_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._winenter_autocmd)
    end
    self._winenter_autocmd = vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave" }, {
        callback = function(e)
            if self._window and vim.api.nvim_get_current_win() == self._window then
                if e.event == "WinEnter" then
                    self._collapsed = false
                else
                    self._collapsed = true
                end
                self:_updateBuffer()
            end
        end,
    })
end

---@private
function Balloon:_buildBufferStart() ---@return integer booffer
    local buffer = vim.api.nvim_create_buf(false, true)

    vim.bo[buffer].buftype = "nofile"
    -- this should delete the buffer from memory when closing the window
    vim.bo[buffer].bufhidden = "wipe"

    vim.diagnostic.enable(false, { bufnr = buffer })

    return buffer
end

---@private
---@param buffer integer
function Balloon:_buildBufferEnd(buffer) ---@return nil void
    if buffer == nil or not vim.api.nvim_buf_is_valid(buffer) then
        return
    end

    vim.bo[buffer].modifiable = false
end

---@private
---@param buffer integer
---@param content BalloonContent|nil
function Balloon:_buildContent(buffer, content) ---@return nil void
    if buffer == nil or not vim.api.nvim_buf_is_valid(buffer) then
        return
    end
    content = content or self:_doBuildContent()

    if self._content and vim.deep_equal(self._content, content) then
        return
    end

    -- we need this to ensure we can set a new content but will switch to false later
    vim.bo[buffer].modifiable = true
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, content.lines)
    for _, mark in ipairs(content.extramarks or {}) do
        vim.api.nvim_buf_set_extmark(buffer, namespace, mark.line, mark.col, mark.opts)
    end
    if self._content then
        for _, listener in ipairs(self._listeners) do
            if type(listener.onContentUpdated) == "function" then
                listener.onContentUpdated(self)
            end
        end
    end
    self._content = content
end

---@private
function Balloon:_doBuildContent() ---@return BalloonContent
    return { lines = {}, extramarks = {} }
end

---@protected
function Balloon:_updateBuffer() ---@return boolean
    if self._buffer == nil or not vim.api.nvim_buf_is_valid(self._buffer) then
        return false
    end

    self:_buildContent(self._buffer)
    self:_buildBufferEnd(self._buffer)

    return true
end

---@protected
function Balloon:_createBuffer() ---@return boolean
    if self._buffer ~= nil then
        return false
    end

    local buffer = self:_buildBufferStart()
    self:_buildContent(buffer)
    self:_buildBufferEnd(buffer)
    self._buffer = buffer
    self:_setupKeymaps(buffer)

    return true
end

---@private
function Balloon:_setupKeymaps(buffer)
    vim.keymap.set("n", "q", function()
        self:dispose()
    end, {
        buffer = buffer,
        nowait = true,
        silent = true,
        desc = "Close notification",
    })
end

local borders_padding = {
    none = 0,
    shadow = 1,
    single = 2,
    double = 2,
    rounded = 2,
    bold = 2,
    solid = 2,
}

---@private
function Balloon:_getBorderVerticalPadding() ---@return integer
    local border = self._border or vim.o.winborder

    if type(border) == "table" then
        local top_border, bottom_border = "", ""

        if #border > 0 and #border <= 4 then
            local part = border[2] or border[1]
            top_border = type(part) == "table" and (part[1] or "") or part
            bottom_border = top_border
        elseif #border == 8 then
            top_border = type(border[2]) == "table" and (border[2][1] or "") or border[2]
            bottom_border = type(border[6]) == "table" and (border[6][1] or "") or border[6]
        end

        return (top_border ~= "" and 1 or 0) + (bottom_border ~= "" and 1 or 0)
    end

    if type(border) == "string" then
        border = vim.split(border, ",")
        if #border == 1 then
            border = border[1]
        elseif #border ~= 8 then
            border = "none"
        end
    end

    if borders_padding[border] ~= nil then
        return borders_padding[border]
    end

    return 0
end

return Balloon
