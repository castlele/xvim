require("cluautils.file_manager")
require("cluautils.string_utils")
require("cluautils.json")
require("cluautils")

-- MARK: - Constants

local workspace_ext = "xcworkspace"
local project_ext = "xcodeproj"
local xvim_conf_file_name = "./xvim.json"
local help_message = [[
// This is a json file, it should be in the root folder of your project to help Xvim build and run it. Run Xvim Help for more detailed information about configuration of this file

]]

---@MARK - Models

XvimError = {
    NO_PROJECT = "No xcodeproj or xcworkspace files in the working directory"
}

---@enum ProjectType
---local ProjectType = {
---    WORKSPACE = "workspace",
---    PROJECT = "project",
---    UNDEFINED = "",
---}
ProjectType = {
    WORKSPACE = "workspace",
    PROJECT = "project",
    UNDEFINED = "",
}

---@enum ConfigurationType
---local ConfigurationType = {
---    DEBUG = "Debug",
---    RELEASE = "Release",
---    CUSTOM = "",
---}
ConfigurationType = {
    DEBUG = "Debug",
    RELEASE = "Release",
    CUSTOM = "",
}

---@class config
---@field project_type ProjectType
---@field project_path string
---@field configuration ConfigurationType
---@field scheme string
---@field simulator_uuid string?
---@field sdk string?
---
---@class environment
---@field open_file fun(file_path: string)
---@field report_error fun(error_message: string)

---@return config
function DefaultConfig()
    return {
        project_type = ProjectType.UNDEFINED,
        project_path = "",
        configuration = ConfigurationType.DEBUG,
        simulator_uuid = nil,
        sdk = nil,
        scheme = "",
    }
end

---@MARK - Private methods

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

---@MARK: - API

---@param file_path string
---@return config?
function ReadConfig(file_path)
    local config_file = io.open(file_path, IOMODE.READ)

    if config_file == nil then
        -- TODO: May be throw some error?
        return nil
    end

    local content = FM.get_lines_from_file(config_file)
    config_file:close()

    return Json.decode(table.concat(content, "\n"))
end

---@param edit_environment environment
function EditConfig(edit_environment)
    edit_environment.open_file(xvim_conf_file_name)
end

---@return boolean | string?
function CreateBuildSettingsFileIfNeeded()
    if not is_any_project_in_working_dir() then
        return XvimError.NO_PROJECT
    end

    if FM.is_file_exists(xvim_conf_file_name) then
        -- TODO: Some what error handling
        return false
    end

    if not FM.create_file(xvim_conf_file_name) then
        -- TODO: Some what error handling
        return false
    end

    FM.write_to_file(xvim_conf_file_name, IOMODE.OVERRIDE, function ()
        local default_config = DefaultConfig()
        local json_config = Json.encode(default_config, { pretty=true, indent="    " })

        return help_message .. json_config
    end)

    return true
end

---@param environment environment?
---@return config?
function GetBuildSettings(environment)
    environment = environment or { report_error=function (_) end }

    local content = FM.get_file_content(xvim_conf_file_name)

    if content == nil then
        environment.report_error("ERROR: Can't get content of the config file")
        return nil
    end

    local decoded_obj = Json.decode(content)

    if decoded_obj == nil or not is_build_settings(decoded_obj) then
        environment.report_error("ERROR: Can't decode build config as json")
        return nil
    end

    return decoded_obj
end

---@param config config
---@return string
function CreateBuildCommand(config)
    -- TODO: update error ...
    local cmd = {"xcodebuild"}

    if not config.project_path:is_empty() then
        local project_cmd = "-" .. config.project_type .. " " .. config.project_path
        table.insert(cmd, project_cmd)
    end

    local configuration = "-configuration " .. config.configuration
    table.insert(cmd, configuration)

    local scheme = "-scheme " .. config.scheme
    table.insert(cmd, scheme)

    if config.sdk ~= nil and not config.sdk:is_empty() then
        local sdk = "-sdk " .. config.sdk
        table.insert(cmd, sdk)
    end

    return table.concat(cmd, " ")
end

---@param config config
function Build(config)
    FM.create_file("./build.log")
    local build_command = "!" .. CreateBuildCommand(config) .. " > ./build.log"

    vim.cmd(build_command)
end

---@param config config
function Run(config)
    print("Run")
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
---
---@param cmd cmd
---@param environment environment
function Xvim(cmd, environment)
    local is_file_created = CreateBuildSettingsFileIfNeeded()

    if is_file_created then
        EditConfig(environment)
    elseif type(is_file_created) == "string" then
        environment.report_error(is_file_created)
        return
    end

    if cmd == nil then
        return
    end

    local settings = GetBuildSettings()

    if settings == nil then
        environment.report_error("ERROR: Can't get build settings!")
        return
    end

    if cmd.args == "Build" then
        Build(settings)
    elseif cmd.args == "Run" then
        Run(settings)
    end
end
