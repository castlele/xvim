require("xvim.models")
require("xvim.flows.xvim_build")
local settings = require("xvim.settings")

require("cluautils.file_manager")
require("cluautils.string_utils")
require("cluautils.table_utils")
require("cluautils.json")
require("cluautils")

---@MARK - Constants

local workspace_ext = "xcworkspace"
local project_ext = "xcodeproj"
local help_message = [[
// This is a json file, it should be in the root folder of your project to help Xvim build and run it. Run Xvim Help for more detailed information about configuration of this file

]]

---@MARK - Private methods

---@return string
local function get_bundle_id()
    local bundle_id_line = io.popen("xcodebuild -showBuildSettings | grep PRODUCT_BUNDLE_IDENTIFIER")
    ---@TODO - Error handling
    local bundle_id = bundle_id_line:read("*l"):split(" = ")[2]

    return bundle_id
end

---@return string
local function get_xcode_path()
    local xcode_path_line = io.popen("xcode-select -p")
    ---@TODO - Error handling
    local xcode_path = xcode_path_line:read("*l")

    return xcode_path
end

---@param config config
---@param device device
---@return string
local function get_app_path(config, device)
    local content = FM.get_dir_content({dir_path=settings.build_directory_path, name_pattern="*.app"})
    ---@TODO: updatge to use configuration
    -- local configuration = config.configuration .. "-" .. device.get_type()
    vim.inspect(content)
    return ""
end

local function is_build_settings(t)
    ---@type config
    local config_to_compare = {
        project_type = ProjectType.UNDEFINED,
        project_path = "",
        configuration = ConfigurationType.DEBUG,
        simulator_uuid = "",
        sdk = "",
        scheme = "",
    }

    for key, _ in pairs(t) do
        if config_to_compare[key] == nil then
            return false
        end
    end

    return true
end

---@return string
local function get_workspace_in_working_dir()
    local content = FM.get_dir_content {
        name_pattern = "*" .. workspace_ext,
        max_depth = 1,
    }

    if #content == 0 then
        return ""
    end

    return content[1]
end

---@return string
local function get_project_in_working_dir()
    local content = FM.get_dir_content {
        name_pattern = "*" .. project_ext,
        max_depth = 1,
    }

    if #content == 0 then
        return ""
    end

    return content[1]
end

local function is_any_project_in_working_dir()
    if not CUtils.is_string_nil_or_empty(get_workspace_in_working_dir()) then
        return true
    end

    return not CUtils.is_string_nil_or_empty(get_project_in_working_dir())
end

---@param t table?
---@return boolean
local function is_valid_configuration_table(t)
   if t == nil then
      return false
   end

   for key, _ in pairs(t) do
      if Config[key] == nil then
         return false
      end
   end

   return true
end

---@MARK: - API

---@param file_path string
---@param environment environment?
---@return config?
function ReadConfig(file_path, environment)
   local config_file = io.open(file_path, IOMODE.READ)

   if config_file == nil then
      if environment ~= nil then
         environment.report_error("Can't open config file at path: " .. file_path)
      end

      return nil
   end

   local content = FM.get_lines_from_file(config_file)
   config_file:close()

   local config = Json.decode(table.concat(content, "\n"))

   if not is_valid_configuration_table(config) then
      return nil
   end

   return config
end

---@param environment environment
function EditConfig(environment)
   environment.open_file(settings.xvim_config_file_name)
end

---@return boolean | string?
function CreateBuildSettingsFileIfNeeded()
   ---@TODO: rename
   local xvim_conf_file_name = settings.xvim_config_file_name

   if not is_any_project_in_working_dir() then
      return XvimError.NO_PROJECT
   end

   if FM.is_file_exists(xvim_conf_file_name) then
      ---@TODO: Some what error handling
      return false
   end

   if not FM.create_file(xvim_conf_file_name) then
      ---@TODO: Some what error handling
      return false
   end

   FM.write_to_file(xvim_conf_file_name, IOMODE.OVERRIDE, function ()
      local json_config = Json.encode(Config, { pretty=true, indent="    " })

      return help_message .. json_config
   end)

   return true
end

---@param environment environment?
---@return config?
function GetBuildConfig(environment)
   environment = environment or { report_error=function (_) end }

   local content = FM.get_file_content(settings.xvim_config_file_name)

   if content == nil then
      environment.report_error("Can't get content of the config file")
      return nil
   end

   local decoded_obj = Json.decode(content)

   if decoded_obj == nil or not is_build_settings(decoded_obj) then
      environment.report_error("Can't decode build config as json")
      return nil
   end

   return decoded_obj
end


---@return table
function GetLogFilesPaths()
   local dir = settings.logs_directory_path

   if dir:sub(#dir, #dir) == "/" then
      dir = dir:sub(1, #dir - 1)
   end

   local all_files = FM.get_dir_content({dir_path=dir, max_depth=2})

   return table.filter(all_files, function(path)
      return path:find("%.log") ~= nil
   end)
end

---@TODO: move to logging.lua
---@param environment environment
function ShowLogs(environment)
   local logs = GetLogFilesPaths()
   environment.show_logs(logs)
end

function CleanLogs()
   local logs = GetLogFilesPaths()

   for _, log in pairs(logs) do
      FM.delete_file(log)
   end
end

---@param config config
---@param environment environment
function Run(config, environment)
   if not environment.is_device_chosen() then
      environment.report_error("Device not chosen. Run 'Sim ShowAll'")
      return
   end

   Build(config, nil, environment)

   ---@TODO: Move to config.device
   local device = environment.get_selected_device()
   local bundle_id = get_bundle_id()
   local xcode_path = get_xcode_path()
   local app_path = get_app_path(config, device)

   if device.status ~= "Booted" then
      os.execute("xcrun simctl boot " .. device.udid)
   end

   os.execute("open " .. xcode_path .. "/Applications/Simulator.app/")
   os.execute("xcrun simctl install booted " .. app_path)
   os.execute("xcrun simctl launch booted " .. bundle_id)
end

---On build configuration:
---If first time:
---* check if configuration file in the root folder and project files is in the root
---* create it with default values, and let the user edit it
---* track if the file was created by the build command and continue building on the file saving (if validation passed)
---* build the project with the config file
---If config file is created and project files is in the root:
---* build the project with the config file
---@class cmd
---@field args args
---
---@alias args
---|> "Build"
---|> "Run"
---|> "ShowLogs"
---|> "CleanLogs"
---
---@param cmd cmd
---@param environment environment
function Xvim(cmd, environment)
   if cmd == nil then
      return
   end

   local is_file_created = CreateBuildSettingsFileIfNeeded()

   if is_file_created then
      EditConfig(environment)
      return

   elseif type(is_file_created) == "string" then
      environment.report_error(is_file_created)
      return
   end

   local config = GetBuildConfig()

   if config == nil then
      environment.report_error(XvimError.NO_BUILD_SETTINGS)
      return
   end

   if cmd.args == "Build" then
      Build(config, nil, environment)
   elseif cmd.args == "Run" then
      Run(config, environment)
   elseif cmd.args == "ShowLogs" then
      ShowLogs(environment)
   elseif cmd.args == "CleanLogs" then
      CleanLogs()
   end
end
