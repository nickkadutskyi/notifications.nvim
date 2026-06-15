local conf = require("notifications.config")
local u = require("notifications.utils")

---@class notifications.NotificationsModelListener
---@field add? fun(self: notifications.NotificationsModelListener, notification: notifications.Notification)
---@field add? fun(self: notifications.NotificationsModelListener, list_of_notifications: notifications.Notification[])
---@field getNotifications? fun(self: notifications.NotificationsModelListener): notifications.Notification[]
---@field clearUnreadStates? fun(self: notifications.NotificationsModelListener)
---@field remove? fun(self: notifications.NotificationsModelListener, notification: notifications.Notification)
---@field expireAll? fun(self: notifications.NotificationsModelListener)
---@field clearTimeline? fun(self: notifications.NotificationsModelListener)
---@field clearAll? fun(self: notifications.NotificationsModelListener)

---@class notifications.NotificationsModel
---@field private _notifications notifications.Notification[]
---@field private _unread notifications.Notification[]
---@field private _listeners notifications.NotificationsModelListener[]
local NotificationsModel = {}
NotificationsModel.__index = NotificationsModel

--- CONSTRUCTORS ---------------------------------------------------------------

---@return notifications.NotificationsModel
function NotificationsModel.new()
    ---@diagnostic disable-next-line: redefined-local
    local self = setmetatable({
        _notifications = {},
        _unread = {},
        _listeners = {},
    }, NotificationsModel)

    return self
end

--- INSTANCE METHODS -----------------------------------------------------------

--- Register a listener that will receive live updates and an initial snapshot.
--- @param newListener notifications.NotificationsModelListener
function NotificationsModel:register(newListener)
    assert(type(newListener) == "table", "Listener must be a table with callback functions")
    for _, l in ipairs(self._listeners) do
        ---@cast l notifications.NotificationsModelListener
        if l == newListener then
            return
        end
    end
    table.insert(self._listeners, newListener)

    -- Deliver initial snapshot as a list (listeners should handle both single and list forms)
    local snapshot = self:getNotifications()
    if #snapshot > 0 then
        local fn = newListener.add
        if type(fn) == "function" then
            pcall(fn, newListener, snapshot)
        end
    end
end

--- Add a notification to the log (history) if it passes the should-log rules.
--- Safe to call multiple times for the same notification (idempotent).
---@param notification notifications.Notification
function NotificationsModel:addNotification(notification)
    if notification == nil or notification:isExpired() then
        return
    end
    if not conf:getSettings(notification:getGroupId()):getShouldLog() then
        return
    end

    table.insert(self._notifications, notification)
    table.insert(self._unread, notification)

    self:_notifyListeners("add", notification)
end

---@return notifications.Notification[]
function NotificationsModel:getUnreadNotifications()
    local result = {}
    for _, n in ipairs(self._unread) do
        result[#result + 1] = n
    end
    return result
end

--- Return true if there are currently no logged notifications.
---@return boolean
function NotificationsModel:isEmpty()
    return #self._notifications == 0
end

---@return notifications.Notification[]
function NotificationsModel:getNotifications()
    local result = {}
    for _, n in ipairs(self._notifications) do
        result[#result + 1] = n
    end
    return result
end

--- Mark all logged notifications as read (clears the "new" state).
function NotificationsModel:markAllRead()
    if #self._unread == 0 then
        return
    end
    self._unread = {}
    self:_notifyListeners("clearUnreadStates")
end

--- Remove a specific notification from the log (and unread).
---@param notification notifications.Notification
function NotificationsModel:remove(notification)
    assert(u.is_a(notification, require("notifications.notification")), "Expected a Notification object.")

    u.removeFromList(self._notifications, notification)
    u.removeFromList(self._unread, notification)

    self:_notifyListeners("remove", notification)
end

--- Expire (and remove) all logged notifications.
--- This will also call :expire() on the notification objects (matching IntelliJ behavior).
function NotificationsModel:expireAll()
    local toExpire = self:getNotifications()

    self._notifications = {}
    self._unread = {}

    self:_notifyListeners("expireAll")

    for _, n in ipairs(toExpire) do
        n:expire()
    end
end

--- Clear the notification timeline.
function NotificationsModel:clearAll()
    self._notifications = {}
    self._unread = {}

    self:_notifyListeners("clearAll")
end

---@private
---@param method "add"|"remove"|"expireAll"|"clearAll"|"clearUnreadStates"
function NotificationsModel:_notifyListeners(method, ...)
    for _, listener in ipairs(self._listeners) do
        local fn = listener[method]
        if type(fn) == "function" then
            pcall(fn, listener, ...)
        end
    end
end

--- Unregister a previously registered listener.
---@param listener notifications.NotificationsModelListener
function NotificationsModel:unregister(listener)
    assert(type(listener) == "table", "Listener must be a table with callback functions")
    u.removeFromList(self._listeners, listener)
end

--- For debugging / inspection.
---@return integer
function NotificationsModel:count()
    return #self._notifications
end

--- SINGLETON ------------------------------------------------------------------

local model = NotificationsModel.new()
return model
