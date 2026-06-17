local namespace = vim.api.nvim_create_namespace("notifications.balloon")

---@class notifications.BalloonListener
---@field onClosed? fun(balloon: notifications.Balloon)
---@field onContentUpdated? fun(balloon: notifications.Balloon)
---@field onWinLeave? fun(balloon: notifications.Balloon)

---@class notifications.Bounds
---@field row integer
---@field col integer
---@field width integer
---@field height integer

---@class notifications.BalloonPosition
---@field row integer
---@field col integer

---@class notifications.BalloonContent
---@field lines string[]
---@field extramarks {line:integer, col: integer, opts:vim.api.keyset.set_extmark}[]

---@class notifications.Balloon
---@field protected _buffer? integer
---@field protected _window? integer
---@field protected _bounds? notifications.Bounds
---@field protected _position? notifications.BalloonPosition
---@field protected _height? integer
---@field protected _maxContentWidth integer
---@field protected _maxContentHeight integer
---@field protected _paddingX integer
---@field protected _listeners notifications.BalloonListener[]
---@field protected _isDisposed boolean
---@field protected _statuscolumn string
---@field private _isVisible boolean
---@field protected _border? any[]|"none"|"single"|"double"|"rounded"|"solid"|"shadow"
---@field private _borderVerticalPadding? integer
---@field private _borderVerticalPaddingBorder? any[]|string
---@field protected _collapsed boolean
---@field private _winenter_autocmd? integer
---@field private _winclosed_autocmd? integer
---@field private _bufwipeout_autocmd? integer
---@field private _content? notifications.BalloonContent
---@field protected _winhighlight string
local Balloon = {}
Balloon.__index = Balloon

--- CONSTRUCTORS ---------------------------------------------------------------

function Balloon.new() ---@return notifications.Balloon balloon
    local self = setmetatable({
        _buffer = nil,
        _window = nil,
        _position = nil,
        _bounds = nil,
        _height = nil,
        _maxContentWidth = 44,
        _maxContentHeight = 4,
        _paddingX = 5,
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
        _borderVerticalPadding = nil,
        _borderVerticalPaddingBorder = nil,
        _collapsed = true,
        _winhighlight = "Normal:NotificationFloatNormal",
    } --[[@as notifications.Balloon]], Balloon)
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

---@param border any[]|"none"|"single"|"double"|"rounded"|"solid"|"shadow"|nil
function Balloon:setBorder(border) ---@return notifications.Balloon balloon
    self._border = border
    self._borderVerticalPadding = nil
    self._borderVerticalPaddingBorder = nil
    return self
end

---@param height integer
function Balloon:setMaxHeight(height) ---@return notifications.Balloon balloon
    self._maxContentHeight = height - self:_getBorderVerticalPadding()
    return self
end

function Balloon:getMaxHeight() ---@return integer
    return self._maxContentHeight + self:_getBorderVerticalPadding()
end

function Balloon:getHeight() ---@return integer|nil
    return self._height ~= nil and (self._height + self:_getBorderVerticalPadding()) or nil
end

function Balloon:setHeight(height) ---@return notifications.Balloon balloon
    self._height = height - self:_getBorderVerticalPadding()
    return self
end

---@param width integer
function Balloon:setWidth(width) ---@return notifications.Balloon balloon
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

---@param bounds notifications.Bounds
function Balloon:setBounds(bounds) ---@return notifications.Balloon balloon
    self._bounds = bounds
    self:setWidth(bounds.width)
    self:setHeight(bounds.height)
    self:_updatePosition(bounds)
    return self
end

---@private
---@param bounds notifications.Bounds
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

function Balloon:hideNowOrWhenCollapsed() ---@return nil void
    if self:isCollapsed() then
        self:dispose()
    else
        self:addListener({
            onWinLeave = function()
                self:dispose()
            end,
        })
    end
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

    if self._winclosed_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._winclosed_autocmd)
        self._winclosed_autocmd = nil
    end

    if self._bufwipeout_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._bufwipeout_autocmd)
        self._bufwipeout_autocmd = nil
    end

    for _, listener in ipairs(self._listeners) do
        if type(listener.onClosed) == "function" then
            listener.onClosed(self)
        end
    end
    self._listeners = {}

    local window = self._window
    self._window = nil
    if window ~= nil and vim.api.nvim_win_is_valid(window) then
        vim.api.nvim_win_close(window, true)
    end

    local buffer = self._buffer
    self._buffer = nil
    if buffer ~= nil and vim.api.nvim_buf_is_valid(buffer) then
        vim.api.nvim_buf_delete(buffer, { force = true })
    end

    self._bounds = nil
    self._position = nil
    self._content = nil

    self:_onAfterDispose()
end

---@protected
function Balloon:_onAfterDispose() ---@return nil void
    -- This method can be overridden by subclasses to perform additional cleanup after disposal
end

function Balloon:isDisposed() ---@return boolean
    return self._isDisposed
end

---@param listener notifications.BalloonListener
function Balloon:addListener(listener) ---@return nil void
    table.insert(self._listeners, listener)
end

---@param bounds? notifications.Bounds|nil
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
    self:_setupWinClosedAutocmd()
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
        winhighlight = self._winhighlight,
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
                    for _, listener in ipairs(self._listeners) do
                        if type(listener.onWinLeave) == "function" then
                            listener.onWinLeave(self)
                        end
                    end
                end
                self:_updateBuffer()
            end
        end,
    })
end

---@private
function Balloon:_setupWinClosedAutocmd()
    if self._winclosed_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._winclosed_autocmd)
        self._winclosed_autocmd = nil
    end

    if self._window == nil or not vim.api.nvim_win_is_valid(self._window) then
        return
    end

    local window = self._window
    self._winclosed_autocmd = vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(window),
        once = true,
        callback = function()
            self._winclosed_autocmd = nil
            if self._window == window then
                self._window = nil
            end
            self:dispose()
        end,
    })
end

---@private
---@param buffer integer
function Balloon:_setupBufWipeoutAutocmd(buffer)
    if self._bufwipeout_autocmd then
        pcall(vim.api.nvim_del_autocmd, self._bufwipeout_autocmd)
        self._bufwipeout_autocmd = nil
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
            self:dispose()
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
---@param content notifications.BalloonContent|nil
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
function Balloon:_doBuildContent() ---@return notifications.BalloonContent
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
    self:_setupBufWipeoutAutocmd(buffer)

    return true
end

---@public
function Balloon:buildBuffer() ---@return boolean
    return self:_createBuffer() or self:_updateBuffer()
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
    if self._borderVerticalPadding ~= nil and self._borderVerticalPaddingBorder == border then
        return self._borderVerticalPadding
    end

    local padding = 0

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

        padding = (top_border ~= "" and 1 or 0) + (bottom_border ~= "" and 1 or 0)
        self._borderVerticalPadding = padding
        self._borderVerticalPaddingBorder = border
        return padding
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
        padding = borders_padding[border]
    end

    self._borderVerticalPadding = padding
    self._borderVerticalPaddingBorder = border
    return padding
end

function Balloon:isCollapsed() ---@return boolean
    return self._collapsed
end

return Balloon
