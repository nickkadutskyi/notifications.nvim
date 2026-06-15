local u = require("notifications.utils")
local logger = require("notifications.logger")

--- Increasing counter for unique notification IDs within the session.
local next_id = 0

---@class notifications.Notification
---@field public id integer
---@field private _groupId string
---@field private _title string
---@field private _subtitle string|nil
---@field private _content string
---@field private _level integer
---@field private _timestamp integer Time (in seconds since Jan 1, 1970) when notification was created.
---@field private _icon string|nil
---@field private _balloon notifications.NotificationBalloon|nil
---@field private _expired boolean
local Notification = {}
Notification.__index = Notification

--- CONSTRUCTOR ----------------------------------------------------------------

---@param groupId string One of the registered groups
---@param title string And optional title, use empty string ("") to display the content without a title
---@param content string
---@param level vim.log.levels
---@return notifications.Notification
---@overload fun(self: notifications.Notification, groupId: string, content: string, level: vim.log.levels): notifications.Notification
---@overload fun(self: notifications.Notification, groupId: string, content: string): notifications.Notification
function Notification.new(groupId, title, content, level)
    -- Handle new(groupId, content) → title becomes ""
    if type(title) == "string" and content == nil then
        content = title
        title = ""
    -- Handle old-style new(groupId, content, level) where level was passed as 3rd arg
    elseif type(content) == "number" and level == nil then
        level = content
        content = title
        title = ""
    end

    next_id = next_id + 1
    local id = next_id
    local timestamp = os.time()

    return setmetatable({
        id = id,
        _timestamp = timestamp,
        _groupId = u.isEmptyStr(groupId) and "default" or groupId,
        _title = title or "",
        _subtitle = nil,
        _content = content or "",
        _level = level or vim.log.levels.INFO,
        _icon = nil,
        _expired = false,
    }, Notification)
end

--- STATIC METHODS -------------------------------------------------------------

--- INSTANCE METHODS -----------------------------------------------------------

function Notification:notify()
    -- Feed the notifications model (history / "tool window" log) at publish time.
    -- By calling the model first here we make the log update happen at the moment the
    -- notification is emitted, before any balloon display or early suppression logic runs.
    require("notifications.notifications_model"):addNotification(self)
    require("notifications.notifications_manager"):showNotification(self)
end

function Notification:getTimestamp()
    return self._timestamp
end

---@return string title
function Notification:getTitle()
    return self._title
end

---@param title string
---@return notifications.Notification
---@overload fun(self: notifications.Notification, title: string, subtitle: string|nil): notifications.Notification
function Notification:setTitle(title, subtitle)
    self._title = title or ""
    if subtitle ~= nil then
        return self:setSubtitle(subtitle)
    end

    return self
end

---@return string|nil subtitle
function Notification:getSubtitle()
    return self._subtitle
end

---@param subtitle string
---@return notifications.Notification
function Notification:setSubtitle(subtitle)
    self._subtitle = subtitle
    return self
end

---@return string groupId
function Notification:getGroupId()
    return self._groupId
end

---@return string content
function Notification:getContent()
    return self._content
end

---@param content string
---@return notifications.Notification
function Notification:setContent(content)
    self._content = content or ""
    return self
end

---@return integer level
function Notification:getLevel()
    return self._level
end

---@return string|nil icon
function Notification:getIcon()
    return self._icon
end

---@param icon string|nil
---@return notifications.Notification
function Notification:setIcon(icon)
    self._icon = icon
    return self
end

---@public
---@param balloon notifications.NotificationBalloon
---@return nil
function Notification:setBalloon(balloon)
    local old_balloon = self._balloon
    self._balloon = balloon
    self:doHideBalloon(old_balloon)
    balloon:addListener({
        onClosed = function()
            -- remove reference to balloon when it is closed to avoid
            -- memory leaks and allow GC to collect it
            if self._balloon == balloon then
                self._balloon = nil
            end
        end,
    })
end

---@return notifications.NotificationBalloon|nil
function Notification:getBalloon()
    return self._balloon
end

---@public
---@overload fun(self: notifications.Notification): nil
function Notification:hideBalloon()
    local balloon = self._balloon
    self._balloon = nil
    self:doHideBalloon(balloon)
end

---@private
---@param balloon notifications.NotificationBalloon|nil
function Notification:doHideBalloon(balloon)
    if balloon ~= nil then
        u.invokeLater(function()
            balloon:hideNowOrWhenCollapsed()
        end)
    end
end

function Notification:expire()
    if self._expired then
        return
    end

    self._expired = true

    u.invokeLater(function()
        self:hideBalloon()
    end)
    require("notifications.notifications_manager"):expire(self)
end

--- PREDICATES -----------------------------------------------------------------

---@return boolean
function Notification:hasTitle()
    return not u.isEmptyStr(self._title) or not u.isEmptyStr(self._subtitle)
end

---@return boolean
function Notification:hasContent()
    return not u.isEmptyStr(self._content)
end

---@throws error if notification has no title and content
function Notification:assertHasTitleOrContent()
    logger:assertTrue(
        self:hasTitle() or self:hasContent(),
        "Notification must have title or/and content; groupId: " .. self._groupId
    )
end

---@return boolean
function Notification:isExpired()
    return self._expired
end

--- METAMETHODS ----------------------------------------------------------------

---@return string
function Notification:__tostring()
    return string.format(
        "Notification{id=%d, groupId='%s', title='%s', subtitle='%s', content='%s', level=%d, timestamp=%d}",
        self.id,
        self._groupId,
        self._title,
        self._subtitle or "",
        self._content,
        self._level,
        self._timestamp
    )
end

---@param other notifications.Notification
---@return boolean
function Notification:__eq(other)
    if type(other) ~= "table" or getmetatable(other) ~= Notification then
        return false
    end

    return self.id == other.id
        and self._groupId == other._groupId
        and self._title == other._title
        and self._subtitle == other._subtitle
        and self._content == other._content
        and self._level == other._level
        and self._icon == other._icon
end

return Notification
