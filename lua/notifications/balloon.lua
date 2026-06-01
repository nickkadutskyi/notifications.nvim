local utils = require("notifications.utils")

---@class BalloonClass
---@field public metatable Balloon
local BalloonClass = {}

local namespace = vim.api.nvim_create_namespace("notifications.balloon")

---@class Balloon
---@field public id string
---@field public groupId string
---@field private _notification Notification
---@field private _buffer integer|nil
---@field private _window integer|nil
---@field private _height integer|nil calculated when buffer is created
---@field private _MAX_TEXT_WIDTH integer
---@field private _MAX_TEXT_LINES integer
---@field private _PADDING_WIDTH integer
---@field private _listeners BalloonListener[]
---@field private _isDisposed boolean
---@field private _preferredWidth integer|nil
---@field private _bounds BalloonBounds
---@field private _position {row: integer, col: integer}|nil
local Balloon = { class = BalloonClass }
Balloon.__index = Balloon

BalloonClass.metatable = Balloon

--- CONSTRUCTORS ---------------------------------------------------------------

---@param notification Notification
function BalloonClass:new(notification)
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({
        id = notification.id,
        groupId = notification:getGroupId(),
        _notification = notification,
        _MAX_TEXT_WIDTH = 44,
        _MAX_TEXT_LINES = 4,
        _PADDING_WIDTH = 3,
        _listeners = {},
        _height = nil,
        _isDisposed = false,
        _preferredWidth = nil,
        _position = nil,
    }, Balloon)
    -- ---@diagnostic disable-next-line: invisible
    -- self:_createBuffer()
    return self
end

--- STATIC METHODS -------------------------------------------------------------

--- Based on window-scoped variables sets an icon in statuscolumn on the first
--- normal line
---@public
function BalloonClass.statuscolumn()
    local win = vim.g.statusline_winid
    local padding = (vim.w[win].notifications_balloon_padding ~= nil and vim.w[win].notifications_balloon_padding or 2)

    -- Currently there is no virtual line but we still check it
    -- so we only draw the icon on the firs regular line
    if vim.v.virtnum ~= 0 then
        return string.rep(" ", padding)
    end

    local icon = vim.w[win].notifications_balloon_icon or ""

    if vim.v.lnum ~= 1 or icon == "" then
        return string.rep(" ", padding)
    end

    local width = vim.fn.strdisplaywidth(icon)
    -- ensure the icon has at least 2 width to let icon render larger
    if width < 2 then
        icon = icon .. string.rep(" ", 2 - width)
    end

    icon = string.rep(" ", padding - 2) .. icon

    local highlight = vim.w[win].notifications_balloon_icon_highlight
    if type(highlight) == "string" and highlight ~= "" then
        return "%#" .. highlight .. "#" .. icon .. "%*"
    end

    return icon
end

--- INSTANCE METHODS -----------------------------------------------------------

---@private
function Balloon:_createBuffer()
    -- Currently we create a buffer only once but in future we will recreate
    -- it on updates to the notification or update content in existing one
    if self._buffer ~= nil then
        return
    end

    self._buffer = vim.api.nvim_create_buf(false, true)

    vim.bo[self._buffer].buftype = "nofile"
    -- this should delete the buffer from memory when closing the window
    vim.bo[self._buffer].bufhidden = "wipe"

    vim.diagnostic.enable(false, { bufnr = self._buffer })

    local raw_title = self._notification:getTitle()
    local raw_subtitle = self._notification:getSubtitle()

    if utils.isEmptyStr(raw_title) and not utils.isEmptyStr(raw_subtitle) then
        raw_title = raw_subtitle --[[@as string]]
        raw_subtitle = nil
    elseif not utils.isEmptyStr(raw_title) and not utils.isEmptyStr(raw_subtitle) then
        raw_title = raw_title .. ": "
    end

    local lines = {} ---@type string[]
    local title ---@type string|nil
    local content = {} ---@type string[]
    local overflow = false ---@type boolean

    if not utils.isEmptyStr(raw_title) then
        title = raw_title .. (not utils.isEmptyStr(raw_subtitle) and raw_subtitle or "")
        title = utils.truncate(title, self._MAX_TEXT_WIDTH)
        table.insert(lines, title)
    end

    content, overflow = utils.wrap(self._notification:getContent(), self._MAX_TEXT_WIDTH, self._MAX_TEXT_LINES - #lines)
    vim.list_extend(lines, content)

    if #lines == 0 then
        lines = { "" }
    end

    -- TODO: make it possible to focus the window and when you focus it should
    --       uncover the full content
    -- WARN: technically it should check if collapsed but there is no such
    --       feature now
    if overflow then
        lines[#lines] = lines[#lines] .. " "
    end

    self._height = math.min(#lines, self._MAX_TEXT_LINES)

    vim.api.nvim_buf_set_lines(self._buffer, 0, -1, false, lines)

    -- apply highlight to the title row
    if not utils.isEmptyStr(title) then
        local title_len = math.min(#title, #raw_title)
        vim.api.nvim_buf_set_extmark(self._buffer, namespace, 0, 0, {
            end_row = 0,
            end_col = title_len,
            hl_group = "NotificationTitle",
        })
        if not utils.isEmptyStr(raw_subtitle) and #raw_title < self._MAX_TEXT_WIDTH then
            local subtitle_len = math.min(#raw_subtitle, self._MAX_TEXT_WIDTH - #raw_title)
            vim.api.nvim_buf_set_extmark(self._buffer, namespace, 0, #raw_title, {
                end_row = 0,
                end_col = #raw_title + subtitle_len,
                hl_group = "NotificationSubtitle",
            })
        end
    end

    vim.bo[self._buffer].modifiable = false
end

---@private
---@return string|nil
function Balloon:_resolveIcon()
    local icon = self._notification:getIcon()
    if not utils.isEmptyStr(icon) then
        return icon
    end

    local level = self._notification:getLevel()
    if level == vim.log.levels.ERROR then
        return "󰀨"
    elseif level == vim.log.levels.WARN then
        return ""
    elseif level == vim.log.levels.INFO then
        return "󰋼"
    else
        return "󰌵"
    end
end

---@private
---@return string
function Balloon:_resolveIconHighlight()
    -- TODO: if custom icon provided check webdev-icons for the highlight
    if not utils.isEmptyStr(self._notification:getIcon()) then
        return "NotificationIconInfo"
    end
    local level = self._notification:getLevel()
    if level == vim.log.levels.ERROR then
        return "NotificationIconError"
    elseif level == vim.log.levels.WARN then
        return "NotificationIconWarn"
    elseif level == vim.log.levels.INFO then
        return "NotificationIconInfo"
    else
        return "NotificationIconHint"
    end
end

---@public
---@param height integer
---@return Balloon
function Balloon:setMaxHeight(height)
    self._MAX_TEXT_LINES = height - 2 -- subtracting borders
    return self
end

---@return integer|nil
function Balloon:getHeight()
    -- Adding 2 for top and bottom borders
    return self._height + 2
end

---@public
function Balloon:buildBuffer()
    self:_createBuffer()
end

---@class BalloonBounds
---@field row integer|nil
---@field col integer|nil
---@field width integer|nil
---@field height integer|nil

---@param bounds BalloonBounds|nil
function Balloon:show(bounds)
    assert(self._isDisposed == false, "Balloon is already disposed")
    -- we create the window only once, to update window params create a different
    -- method
    if self._window ~= nil then
        return
    end

    bounds = bounds or self._bounds
    if bounds.width ~= nil then
        self:setWidth(bounds.width)
    end
    if bounds.height ~= nil then
        self:setMaxHeight(bounds.height)
    end

    self:_createBuffer()

    -- detracting borders
    local width = self:getWidth() - 2
    local height = self:getHeight() - 2

    self._position = {
        row = bounds.row,
        col = bounds.col,
    }

    self._window = vim.api.nvim_open_win(self._buffer, false, {
        relative = "editor",
        width = width,
        height = height,
        row = self._position.row,
        col = self._position.col,
        style = "",
        border = {
            { "▕", "NotificationFloatBorderOuter" }, -- Top Left corner
            { "▔", "NotificationFloatBorder" }, -- Title border
            { "▏", "NotificationFloatBorderOuter" }, -- Top Right corner
            { "▏", "NotificationFloatBorderOuter" },
            { "▏", "NotificationFloatBorderOuter" },
            { "▁", "NotificationFloatBorder" }, -- Footer border
            { "▕", "NotificationFloatBorderOuter" },
            { "▕", "NotificationFloatBorderOuter" },
        },
        zindex = 50,
        focusable = false,
    })

    vim.w[self._window].notifications_balloon_icon = self:_resolveIcon()
    vim.w[self._window].notifications_balloon_icon_highlight = self:_resolveIconHighlight()
    vim.w[self._window].notifications_balloon_padding = self._PADDING_WIDTH

    self:_configureWindow()
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
        statuscolumn = "%!v:lua.require'notifications.balloon'.statuscolumn()",
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

---@public
function Balloon:hide()
    if self._isDisposed then
        return
    end

    self._isDisposed = true

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

function Balloon:dispose()
    self:hide()
end

---@class BalloonListener
---@field onClosed fun(balloon: Balloon)

---@public
---@param listener BalloonListener
---@return nil
function Balloon:addListener(listener)
    table.insert(self._listeners, listener)
end

---@public
---@return boolean
function Balloon:isDisposed()
    return self._isDisposed
end

---@public
---@param width integer
---@return Balloon
function Balloon:setWidth(width)
    self._MAX_TEXT_WIDTH = width
        -- subtracting right padding
        - self._PADDING_WIDTH
        -- subtracting left padding
        - math.max(self._PADDING_WIDTH, 2)
        -- subtracting borders
        - 2
    return self
end

---@return integer width width
function Balloon:getWidth()
    return self._MAX_TEXT_WIDTH
        -- right padding
        + self._PADDING_WIDTH
        -- left padding will always be at least 2 characters because of the icon
        + math.max(2, self._PADDING_WIDTH)
        -- adding 2 for the border
        + 2
end

---@param bounds BalloonBounds
function Balloon:setBounds(bounds)
    self._bounds = bounds
    if self._position then
        self:_updatePosition(bounds)
    end
end

---@private
function Balloon:_updatePosition(bounds)
    if self._window == nil or self._position == nil then
        return
    end

    self._position = {
        row = bounds.row,
        col = bounds.col,
    }

    utils.invokeLater(function()
        vim.api.nvim_win_set_config(self._window, {
            relative = "editor",
            row = self._position.row,
            col = self._position.col,
        })
    end)
end

return BalloonClass
