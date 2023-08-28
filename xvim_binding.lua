require("xvim_vim_ui")
require("xvim")

local buildArg = 'Build'
local runArg = 'Run'

---@MARK - Environment

local function report_error(message)
    vim.notify(message, vim.log.levels.WARN)
end

---@type environment
local vim_environment = {
    open_file = UI.open_file_in_split_window,
    report_error = report_error
}

---@MARK - Command helpers

local function completion(_, _, _)
    return { buildArg, runArg }
end

local function xvim_wrapper(args)
    Xvim(args, vim_environment)
end

vim.api.nvim_create_user_command("Xvim", xvim_wrapper, { desc="Xvim", complete=completion, nargs=1 })
