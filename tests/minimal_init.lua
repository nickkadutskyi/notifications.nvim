-- tests/minimal_init.lua
-- Minimal init for running tests with plenary.busted
--
-- Usage (recommended):
--   make test
--
-- Advanced / manual:
--   nvim --headless --noplugin -u tests/minimal_init.lua
--
-- All *_spec.lua files under tests/ are discovered and executed automatically.

local M = {}

local function bootstrap_plenary()
    local plenary_path = os.getenv("PLENARY_DIR")
    local cloned = false

    if not plenary_path or vim.fn.isdirectory(plenary_path) == 0 then
        plenary_path = "/tmp/plenary.nvim"
        if vim.fn.isdirectory(plenary_path) == 0 then
            print("[notifications.nvim tests] Cloning plenary.nvim into " .. plenary_path .. " ...")
            local result = vim.fn.system({
                "git", "clone", "--depth=1",
                "https://github.com/nvim-lua/plenary.nvim",
                plenary_path,
            })
            local exit_code = vim.v.shell_error
            if exit_code ~= 0 then
                print("[notifications.nvim tests] git clone failed (code " .. exit_code .. "):")
                print(result)
                vim.cmd("qa!")
                os.exit(1)
            end
            cloned = true
        end
    end

    vim.opt.rtp:prepend(plenary_path)

    -- Verify the expected plenary files exist
    if vim.fn.isdirectory(plenary_path .. "/lua/plenary") == 0 then
        print("[notifications.nvim tests] Plenary directory looks broken: " .. plenary_path)
        print("Try: rm -rf " .. plenary_path .. "  and re-run make test")
        vim.cmd("qa!")
        os.exit(1)
    end

    if cloned then
        print("[notifications.nvim tests] Plenary cloned successfully.")
    end

    return plenary_path
end

function M.setup()
    -- Add current plugin to rtp so we can require("notifications.*")
    vim.opt.rtp:prepend(vim.fn.getcwd())

    -- Ensure vim.log.levels exists (always true inside real Neovim)
    if not vim.log then
        vim.log = {}
    end
    vim.log.levels = vim.log.levels or {
        TRACE = 0,
        DEBUG = 1,
        INFO = 2,
        WARN = 3,
        ERROR = 4,
        OFF = 5,
    }

    -- Bootstrap plenary only if we want busted runner
    local plenary_path = bootstrap_plenary()

    -- Load plenary busted (this registers some helpers)
    local ok, err = pcall(require, "plenary.busted")
    if not ok then
        print("[notifications.nvim tests] Failed to require('plenary.busted') from: " .. plenary_path)
        print("Error: " .. tostring(err))
        print("")
        print("Try removing the directory and letting it re-clone:")
        print("  rm -rf " .. plenary_path)
        print("  make test")
        vim.cmd("qa!")
        os.exit(1)
    end

    print("[notifications.nvim tests] plenary loaded successfully.")
end

M.setup()

-- Run the tests programmatically.
-- This is more reliable than depending on the :PlenaryBustedDirectory user command
-- (especially under --headless --noplugin).
local has_harness, harness = pcall(require, "plenary.test_harness")
if not has_harness then
    print("[notifications.nvim tests] Could not load plenary.test_harness")
    vim.cmd("qa!")
    os.exit(1)
end

-- This will discover and run all *_spec.lua files and then exit Neovim.
harness.test_directory("tests", {
    -- You can add more options here if needed
})

-- We usually don't reach here because test_harness calls qa! internally,
-- but just in case:
vim.cmd("qa!")
return M
