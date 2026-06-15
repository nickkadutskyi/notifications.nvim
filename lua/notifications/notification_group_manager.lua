local logger = require("notifications.logger")

local NotificationGroup = require("notifications.notification_group")
local NotificationDisplayType = require("notifications.notification_display_type")

---@class notifications.NotificationGroupPluginConfig
---@field id string
---@field displayType notifications.NotificationDisplayType
---@field displayName string|nil
---@field pluginId string|nil
---@field isLogByDefault boolean|nil

---@class NotificationGroupManager
---@field private _registeredGroups table<string, notifications.NotificationGroup>
local NotificationGroupManager = {}
NotificationGroupManager.__index = NotificationGroupManager

function NotificationGroupManager.new() ---@return NotificationGroupManager
    local self = setmetatable({
        _registeredGroups = {},
    }, NotificationGroupManager)

    ---@diagnostic disable-next-line: invisible
    self:_addPluginListener()
    ---@diagnostic disable-next-line: invisible
    self._registeredGroups = self:_computeGroups()
    ---@diagnostic disable-next-line: invisible
    self:_registerNotificationGroup(
        {
            id = "default",
            displayType = NotificationDisplayType.BALLOON,
            displayName = "Default",
            pluginId = "notifications.nvim",
            isLogByDefault = true,
        },
        ---@diagnostic disable-next-line: invisible
        self._registeredGroups
    )
    ---@diagnostic disable-next-line: invisible
    self:_registerNotificationGroup(
        {
            id = "default-sticky",
            displayType = NotificationDisplayType.STICKY_BALLOON,
            displayName = "Default Sticky",
            pluginId = "notifications.nvim",
            isLogByDefault = true,
        },
        ---@diagnostic disable-next-line: invisible
        self._registeredGroups
    )

    return self
end

--- INSTNACE METHODS -----------------------------------------------------------

---@param groupId string
function NotificationGroupManager:isGroupRegistered(groupId) ---@return boolean
    return self._registeredGroups[groupId] ~= nil
end

---@param groupId string
function NotificationGroupManager:getNotificationGroup(groupId) ---@return notifications.NotificationGroup|nil
    return self._registeredGroups[groupId]
end

---@private
function NotificationGroupManager:_computeGroups() ---@return table<string, notifications.NotificationGroup>
    ---@type table<string, notifications.NotificationGroup>
    local result = {}

    self:_processWithPlugins(function(plugin)
        self:_registerNotificationGroup(plugin, result)
    end)

    return result
end

---@private
---@param plugin notifications.NotificationGroupPluginConfig
---@param registeredGroups table<string, notifications.NotificationGroup>
function NotificationGroupManager:_registerNotificationGroup(plugin, registeredGroups) ---@return nil void
    local groupId = plugin.id

    if groupId == nil then
        logger:warn('Cannot create notification group for plugin "%s": id should be not null', plugin.pluginId)
        return
    end

    local displayType = plugin.displayType
    if displayType == nil then
        logger:warn('Cannot create notification group "%s": displayType should be not null', groupId)
        return
    end
    local title = plugin.displayName

    local notificationGroup = NotificationGroup.new(groupId, displayType, title, plugin.pluginId, plugin.isLogByDefault)
    local old = registeredGroups[groupId]
    registeredGroups[groupId] = notificationGroup
    if old ~= nil then
        logger:warn(
            'Notification group "%s" from "%s" is overriding existing one from "%s"',
            groupId,
            plugin.pluginId,
            old.pluginId
        )
    end
end

---@private
---@param callback fun(plugin: notifications.NotificationGroupPluginConfig)
function NotificationGroupManager:_processWithPlugins(callback) ---@return nil void
    self:_processPluginPaths(vim.api.nvim_get_runtime_file("lua/", true), function(plugin)
        callback(plugin)
    end)
    self:_processPluginPaths(vim.fn.getscriptinfo(), function(plugin)
        callback(plugin)
    end)
end

---@private
function NotificationGroupManager:_addPluginListener() ---@return nil void
    local group = vim.api.nvim_create_augroup("NotificationsGroupManager", { clear = true })

    vim.api.nvim_create_autocmd("SourcePost", {
        group = group,
        callback = function(args)
            self:_processPluginPaths({ args.file }, function(plugin)
                self:_registerNotificationGroup(plugin, self._registeredGroups)
            end)
        end,
    })
    vim.api.nvim_create_autocmd("OptionSet", {
        group = group,
        pattern = "runtimepath",
        callback = function(args)
            -- Traverse runtimepath and re-register all plugins,
            -- this is needed to support plugins being added/removed from runtimepath at runtime
            local paths = vim.api.nvim_get_runtime_file("lua/", true)
            self:_processPluginPaths(paths, function(plugin)
                self:_registerNotificationGroup(plugin, self._registeredGroups)
            end)
        end,
    })
end

---@private
---@param paths string[]|{name:string}[]
---@param callback fun(plugin: notifications.NotificationGroupPluginConfig)
function NotificationGroupManager:_processPluginPaths(paths, callback) ---@return nil void
    vim.iter(paths)
        :map(function(path)
            if type(path) == "table" then
                return path.name
            end
            return path
        end)
        :filter(function(path)
            return type(path) == "string"
        end)
        :each(
            ---@param path string
            function(path)
                local patterns = {
                    "([^/]*/[^/]*/[^/]*)/lua/$",
                    "([^/]*/opt/[^/]*)/plugin/[^/]*$",
                    "([^/]*/opt/[^/]*)/ftplugin/[^/]*$",
                    "([^/]*/opt/[^/]*)/syntax/[^/]*$",
                    "([^/]*/opt/[^/]*)/colors/[^/]*$",
                    "([^/]*/opt/[^/]*)/after/plugin/[^/]*$",
                    "([^/]*/opt/[^/]*)/after/ftplugin/[^/]*$",
                    "([^/]*/opt/[^/]*)/after/syntax/[^/]*$",
                    "([^/]*/opt/[^/]*)/after/colors/[^/]*$",
                    "([^/]*/colors/[^/]*)$",
                    "([^/]*/plugin/[^/]*)$",
                    "([^/]*/syntax/[^/]*)$",
                    "([^/]*/[^/]*/runtime)/[^/]*.lua$",
                    "([^/]*/[^/]*/runtime)/[^/]*.vim$",
                    "([^/]*/[^/]*/nvim)/[^/]*.lua$",
                    "([^/]*/[^/]*/nvim)/[^/]*.vim$",
                }
                local pluginId = nil
                for _, pattern in ipairs(patterns) do
                    pluginId = path:match(pattern)
                    if pluginId ~= nil and pluginId ~= "" then
                        break
                    end
                end

                local pluginConfig = {
                    id = pluginId,
                    displayType = NotificationDisplayType.BALLOON,
                    displayName = pluginId,
                    pluginId = pluginId,
                    isLogByDefault = true,
                }

                callback(pluginConfig)
            end
        )
end

--- Since it is creating autocmds we make it a singleton to avoid multiple unhandled autocmds
local manager = NotificationGroupManager.new()
return manager
