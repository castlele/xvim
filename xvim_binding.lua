require("xvim_vim_ui")
require("xvim")

local build_arg = "Build"
local run_arg = "Run"
local show_logs = "ShowLogs"

---@MARK - Environment

local function report_error(message)
    vim.notify(message, vim.log.levels.WARN)
end

---@type environment
local vim_environment = {
    open_file = UI.open_file_in_split_window,
    report_error = report_error,
    show_logs = UI.show_logs_quick_fix_window,
}

---@MARK - Command helpers

local function completion(_, _, _)
    return { build_arg, run_arg, show_logs }
end

local function xvim_wrapper(args)
    Xvim(args, vim_environment)
end

vim.api.nvim_create_user_command("Xvim", xvim_wrapper, { desc="Xvim", complete=completion, nargs=1 })
