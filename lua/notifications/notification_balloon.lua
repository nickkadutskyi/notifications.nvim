local Balloon = require("notifications.balloon")

local u = require("notifications.utils")

---@class NotificationBalloon: Balloon
---@field public id integer
---@field public groupId string
---@field private _notification Notification
local NotificationBalloon = {}
NotificationBalloon.__index = NotificationBalloon
setmetatable(NotificationBalloon, Balloon)

--- CONSTRUCTORS ---------------------------------------------------------------

---@param notification Notification
function NotificationBalloon.new(notification) ---@return NotificationBalloon
    local self = setmetatable(Balloon.new(), NotificationBalloon) --[[@as NotificationBalloon]]
    self.id = notification.id
    self.groupId = notification:getGroupId()
    self._notification = notification
    self._statuscolumn = "%!v:lua.require'notifications.notification_balloon'.statuscolumn()"
    return self
end

--- STATIC METHODS -------------------------------------------------------------

--- Based on window-scoped variables sets an icon in statuscolumn on the first
--- normal line
---@public
function NotificationBalloon.statuscolumn()
    local win = vim.g.statusline_winid
    local padding = (vim.w[win].balloon_padding ~= nil and vim.w[win].balloon_padding or 2)

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
---@return string|nil
function NotificationBalloon:_resolveIcon()
    local icon = self._notification:getIcon()
    if not u.isEmptyStr(icon) then
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
function NotificationBalloon:_resolveIconHighlight()
    -- TODO: if custom icon provided check webdev-icons for the highlight
    if not u.isEmptyStr(self._notification:getIcon()) then
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
function NotificationBalloon:buildBuffer() ---@return boolean
    return self:_createBuffer() or self:_updateBuffer()
end

---@private
function NotificationBalloon:_setWindowVariables()
    if self._window == nil or not vim.api.nvim_win_is_valid(self._window) then
        return
    end

    vim.w[self._window].notifications_balloon_icon = self:_resolveIcon()
    vim.w[self._window].notifications_balloon_icon_highlight = self:_resolveIconHighlight()
    vim.w[self._window].balloon_padding = self._paddingX
end

---@private
function NotificationBalloon:_doBuildContent() ---@return BalloonContent
    local raw_title = self._notification:getTitle()
    local raw_subtitle = self._notification:getSubtitle()

    if u.isEmptyStr(raw_title) and not u.isEmptyStr(raw_subtitle) then
        raw_title = raw_subtitle --[[@as string]]
        raw_subtitle = nil
    elseif not u.isEmptyStr(raw_title) and not u.isEmptyStr(raw_subtitle) then
        raw_title = raw_title .. ": "
    end

    local lines = {} ---@type string[]
    local extramarks = {} ---@type {line:integer, col: integer, opts:vim.api.keyset.set_extmark}[]

    local title ---@type string|nil
    local short_cont = {} ---@type string[]
    local full_cont = {} ---@type string[]
    local overflowed = false ---@type boolean

    if not u.isEmptyStr(raw_title) then
        title = raw_title .. (not u.isEmptyStr(raw_subtitle) and raw_subtitle or "")
        title = u.truncate(title, self._maxContentWidth)
        table.insert(lines, title)
    end

    short_cont, full_cont, overflowed =
        u.wrap(self._notification:getContent(), self._maxContentWidth, self._maxContentHeight - #lines)
    vim.list_extend(lines, self._collapsed and short_cont or full_cont)

    if overflowed then
        local line_width = vim.fn.strdisplaywidth(lines[#lines])
        local prefix_width = math.max(1, self._maxContentWidth - line_width + self._paddingX - 3)
        local suffix = self._collapsed and "  " or "  "
        lines[#lines] = lines[#lines] .. string.rep(" ", prefix_width) .. suffix
    end

    if #lines == 0 then
        lines = { "" }
    end

    self._height = self._collapsed and math.min(#lines, self._maxContentHeight) or #lines

    if not u.isEmptyStr(title) then
        local title_len = math.min(#title, #raw_title)
        table.insert(extramarks, {
            line = 0,
            col = 0,
            opts = {
                end_row = 0,
                end_col = title_len,
                hl_group = "NotificationTitle",
            },
        })
        if not u.isEmptyStr(raw_subtitle) and #raw_title < self._maxContentWidth then
            table.insert(extramarks, {
                line = 0,
                col = #raw_title,
                opts = {
                    end_row = 0,
                    end_col = #raw_title + math.min(#raw_subtitle, self._maxContentWidth - #raw_title),
                    hl_group = "NotificationSubtitle",
                },
            })
        end
    end
    return { lines = lines, extramarks = extramarks }
end

return NotificationBalloon
