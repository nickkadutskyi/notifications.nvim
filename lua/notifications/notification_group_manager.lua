local NotificationGroup = require("notifications.notification_group")
local NotificationDisplayType = require("notifications.notification_display_type")

---@class NotificationGroupPluginConfig
---@field id string
---@field displayType NotificationDisplayType
---@field displayName string|nil
---@field pluginId string|nil

---@class NotificationGroupManagerClass
local NotificationGroupManagerClass = {}

---@class NotificationGroupManager
---@field private _registeredGroups table<string, NotificationGroup>
local NotificationGroupManager = {}
NotificationGroupManager.__index = NotificationGroupManager

---@return NotificationGroupManager
function NotificationGroupManagerClass:new()
    self = setmetatable({
        _registeredGroups = {},
    }, NotificationGroupManager)

    ---@diagnostic disable-next-line: invisible
    self:addPluginListener()
    ---@diagnostic disable-next-line: invisible
    self:registerNotificationGroup({
        id = "default",
        displayType = NotificationDisplayType.BALLOON,
        displayName = "Default",
        pluginId = "notifications.nvim",
    }, self._registeredGroups)
    ---@diagnostic disable-next-line: invisible
    self._registeredGroups = self:computeGroups()

    -- vim.defer_fn(function()
    --     local ids = vim.iter(self._registeredGroups)
    --         :map(
    --             ---@param v NotificationGroup
    --             function(_, v)
    --                 return v.displayId
    --             end
    --         )
    --         :totable()
    --
    --     -- vim.notify("Manager Constructted" .. vim.inspect({
    --     --     numreg = #ids,
    --     --     ids = ids,
    --     -- }))
    -- end, 5000)

    return self
end

--- INSTNACE METHODS -----------------------------------------------------------

---@param displayId string
---@return boolean
function NotificationGroupManager:isGroupRegistered(displayId)
    return self._registeredGroups[displayId] ~= nil
end

---@private
---@return table<string, NotificationGroup>
function NotificationGroupManager:computeGroups()
    ---@type table<string, NotificationGroup>
    local result = {}

    self:processWithPlugins(function(plugin)
        self:registerNotificationGroup(plugin, result)
    end)

    return result
end

---@private
---@param plugin NotificationGroupPluginConfig
---@param registeredGroups table<string, NotificationGroup>
function NotificationGroupManager:registerNotificationGroup(plugin, registeredGroups)
    local groupId = plugin.id

    if groupId == nil or registeredGroups[groupId] then
        return
    end

    local displayType = plugin.displayType
    local title = plugin.displayName

    local notificationGroup = NotificationGroup:new(groupId, displayType, title, plugin.pluginId)
    registeredGroups[groupId] = notificationGroup
end

---@private
---@param callback fun(plugin: NotificationGroupPluginConfig)
function NotificationGroupManager:processWithPlugins(callback)
    self:processPluginPaths(vim.api.nvim_get_runtime_file("lua/", true), function(plugin)
        callback(plugin)
    end)
    self:processPluginPaths(vim.fn.getscriptinfo(), function(plugin)
        callback(plugin)
    end)
end

---@private
function NotificationGroupManager:addPluginListener()
    local group = vim.api.nvim_create_augroup("NotificationsGroupManager", { clear = true })

    vim.api.nvim_create_autocmd("SourcePost", {
        group = group,
        callback = function(args)
            self:processPluginPaths({ args.file }, function(plugin)
                self:registerNotificationGroup(plugin, self._registeredGroups)
            end)
        end,
    })
    vim.api.nvim_create_autocmd("OptionSet", {
        group = group,
        pattern = "runtimepath",
        callback = function(args)
            -- vim.notify("Runtimepath changed, re-registering notification groups")
            -- Traverse runtimepath and re-register all plugins,
            -- this is needed to support plugins being added/removed from runtimepath at runtime
            local paths = vim.api.nvim_get_runtime_file("lua/", true)
            self:processPluginPaths(paths, function(plugin)
                self:registerNotificationGroup(plugin, self._registeredGroups)
            end)
        end,
    })
end

---@private
---@param paths string[]|{name:string}[]
---@param callback fun(plugin: NotificationGroupPluginConfig)
function NotificationGroupManager:processPluginPaths(paths, callback)
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
                }

                callback(pluginConfig)
            end
        )
end

--- Since it is creating autocmds we make it a singleton to avoid multiple unhandled autocmds
local manager = NotificationGroupManagerClass:new()
return manager
