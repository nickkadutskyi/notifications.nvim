-- Inits tabpage manager
require("notifications.tab_manager")
-- Inits notification manager
require("notifications.notifications_manager")

local notifications = require("notifications")

vim.api.nvim_create_user_command("NotificationsTestShort", function()
    notifications.notify("This is a short notification.", vim.log.levels.INFO, { title = "Short Title" })
end, {})

vim.api.nvim_create_user_command("NotificationsTestLongTitle", function()
    notifications.notify("Short body.", vim.log.levels.INFO, {
        title = "This is a very long notification title that should get truncated with ellipsis because it exceeds the limit",
    })
end, {})

vim.api.nvim_create_user_command("NotificationsTestLongContent", function()
    notifications.notify(
        "This is a long single line of content that should automatically wrap inside the balloon window using the available width. It should flow across multiple visual lines without manual newlines.",
        vim.log.levels.INFO,
        { title = "Wrapping Test" }
    )
end, {})

vim.api.nvim_create_user_command("NotificationsTestMultiLineContent", function()
    notifications.notify(
        "Line one of content. Line two continues here with more text to force wrapping. Line three adds even more characters so the balloon uses all three available content lines. This tests that wrapping works correctly within the fixed height.",
        vim.log.levels.INFO,
        { title = "Multi-line Content" }
    )
end, {})

vim.api.nvim_create_user_command("NotificationsTestLongTitleMultilineContent", function()
    notifications.notify(
        "This is a long multiline notification. The title above is very long and should be truncated with an ellipsis. Meanwhile, this content should wrap properly across multiple lines inside the 4-line balloon height, testing both long title truncation and automatic content wrapping at the same time.",
        vim.log.levels.INFO,
        {
            title = "This is an extremely long title that is designed to exceed 45 characters so it gets truncated with ellipsis characters at the end",
        }
    )
end, {})

vim.api.nvim_create_user_command("NotificationsTestNoTitle", function()
    notifications.notify(
        "This notification has no title, so the content should start on the first row and use all four rows. This sentence is intentionally longer to verify that no-title notifications wrap into the full available height instead of reserving space for a missing title.",
        vim.log.levels.INFO
    )
end, {})

vim.api.nvim_create_user_command("NotificationsTestTitleSubtitle2", function()
    notifications.notify(
        "This is the main content area testing both title and subtitle displaying correctly.",
        vim.log.levels.INFO,
        {
            title = "My Title which is super long so overflow",
            subtitle = "My Subtitle",
        }
    )
end, {})

vim.api.nvim_create_user_command("NotificationsTestTitleSubtitle", function()
    notifications.notify(
        "This is the main content area testing bothse title and subtitle displaying correctly.",
        vim.log.levels.INFO,
        {
            title = "My Title",
            subtitle = "My Subtitle",
        }
    )
end, {})

vim.api.nvim_create_user_command("NotificationsTestError", function()
    notifications.notify("Something went wrong in the system.", vim.log.levels.ERROR, { title = "Error Title" })
end, {})

vim.api.nvim_create_user_command("NotificationsTestHint", function()
    notifications.notify("Here is a helpful tip or hint.", vim.log.levels.DEBUG, { title = "Hint Title" })
end, {})

vim.api.nvim_create_user_command("NotificationsTestWarn", function()
    notifications.notify(
        "This is a warning message. Proceed with caution.",
        vim.log.levels.WARN,
        { title = "Warning Title" }
    )
end, {})

vim.api.nvim_create_user_command("NotificationsTestWithIcon", function()
    notifications.notify(
        "This balloon uses a custom star icon instead of the default level-based one.",
        vim.log.levels.INFO,
        {
            title = "Custom Icon",
            icon = "★",
        }
    )
end, {})

vim.api.nvim_create_user_command("NotificationsTestStack", function()
    for i = 1, 5 do
        notifications.notify("Testing multiple balloons stacking in the corner.", vim.log.levels.INFO, {
            title = "Stacked #" .. i,
        })
    end
end, {})

vim.api.nvim_create_user_command("NotificationsTestDelay", function()
    -- Start a libuv timer
    local timer = vim.uv.new_timer()
    timer:start(
        3000,
        0,
        vim.schedule_wrap(function()
            notifications.notify("This notification appeared after a 3 second delay.", vim.log.levels.INFO, {
                title = "Delayed Notification",
            })
            timer:close()
        end)
    )
end, {})
