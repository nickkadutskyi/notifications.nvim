# 🔔 notifications.nvim

<p>Notifications for Neovim</p>

## Features
- `vim.notify` compatible `notify(msg, level, opts)` API
- Notification balloons with title, subtitle, icon, and level-based styling
- Configurable per-group display types (balloon, sticky balloon, etc.)
- User configuration via `setup()` for balloon notifications and group settings
- Automatic icon and highlight resolution based on log level
- Collapsible/expandable balloon content with overflow indicators
- Notifications expire and clean up associated UI elements

## Installation
n/a

## Configuration
n/a

## Contributing
n/a

## TODO
- [ ] Add screencast to README to show how it works and looks like
- [ ] Link highlight groups so ti works well with popular colorscheme
- [ ] Configuration
    - [ ] on/off display balloon notifications
    - [ ] on/off system notifications
    - [ ] per group config popup type (sticky balloon, balloon, tool window balloon, none)
    - [ ] per group config on/off show in tool window
- [ ] Notification Balloon
    - [ ] When focused show notification's group somewhere
    - [ ] Decide if I need to keep the balloon if I interacted with it
    - [ ] Better navigation from code to notification balloon and between balloons
    - [ ] Integrate with webdev-icons plugin for better icon coloring
- [ ] Notification Actions
    - [ ] Dismiss notification action ("Don't show again", "Don't show again for this project") and restore if needed
    - [ ] Custom actions
    - [ ] Add probable actions for common critical suggestions from `:checkhealth`
- [ ] Notifications tool window
    - [ ] All notifications stay in tool window until manually cleared or restarted
    - [ ] Timeline Section for all regular notifications/events in sequential order
    - [ ] Suggestions Section to help optimize IDE, e.g. missing components, plugins, disabled options, can prompt you
          to change configuration
        - [ ] Integrate with `:checkhealth` to generate suggestions for critical issues
- [ ] `lualine.nvim` plugins
    - [ ] Show bell icon with a state indicating that there are uncleared notifications in the tool window
    - [ ] Show the most recent event message
        - [ ] Right click to copy the message
        - [ ] Left click to open it in Notifications tool window
    - [ ] Show progress of processes
        - [ ] Left click to reveal Processes manager
- [ ] Processes Manager (TBD) used for LSP progress and overseer.nvim task progress and similar stuff
- [ ] Tool Window Notifications where notifications appear in popups and are connected to specific tool windows

