require("xvim.xvim_vim_ui")
require("xvim.sim")
require("xvim.xvim")
local logger = require("xvim.logging")

---@TODO - seems like bad approach :)
---@type device?
local active_device = nil
---@TODO - create enum out of in in main module
local build_arg = "Build"
local run_arg = "Run"
local show_logs = "ShowLogs"
local clean_logs = "CleanLogs"
local show_all_arg = "ShowAll"

---@MARK - Environment

---@param message string
local function report_error(message)
   vim.notify("ERROR: " .. message, vim.log.levels.WARN)
end

---@return device
local function get_selected_device()
   return active_device
end

---@return boolean
local function is_device_chosen()
   return active_device ~= nil
end

---@type environment
local vim_environment = {
   open_file            = UI.open_file_in_split_window,
   show_logs            = UI.show_logs_quick_fix_window,
   report_error         = report_error,
   show_all_devices     = UI.show_all_devices,
   get_selected_device  = get_selected_device,
   is_device_chosen     = is_device_chosen,
   create_log_file_name = logger.create_log_file_name
}

---@MARK - Command helpers

local function completion(_, _, _)
   return { build_arg, run_arg }
end

local function sim_completion(_, _, _)
   return { show_all_arg }
end

local function logs_completion(_, _, _)
   return { show_logs, clean_logs }
end

local function show_devices(args)
   if args.args == show_all_arg then
      local devices = GetAvailableDevices()
      local devices_plain_list = table.concat_tables(devices.physical, devices.simulators)

      vim_environment.show_all_devices(devices, function (index)
         active_device = devices_plain_list[index]
      end)
   end
end

local function logs_wrapper(args)
   assert(false, "Logs wrapper not implemented")
end

local function xvim_wrapper(args)
   Xvim(args, vim_environment)
end

---@MARK - Command bindings

vim.api.nvim_create_user_command("Xvim", xvim_wrapper, { desc="Xvim", complete=completion, nargs=1 })
vim.api.nvim_create_user_command("Xsim", show_devices, { desc="Xsim", complete=sim_completion, nargs=1 })
vim.api.nvim_create_user_command("Xlogs", logs_wrapper, { desc="Xlogs", complete=logs_completion, nargs=1 })
