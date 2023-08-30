---@enum XvimError
XvimError = {
    NO_PROJECT = "No xcodeproj or xcworkspace files in the working directory",
    NO_BUILD_SETTINGS = "Can't get build settings",
}

---@enum ProjectType
ProjectType = {
    WORKSPACE = "workspace",
    PROJECT = "project",
    UNDEFINED = "",
}

---@enum ConfigurationType
ConfigurationType = {
    DEBUG = "Debug",
    RELEASE = "Release",
    CUSTOM = "",
}

---@class environment
---@field open_file fun(file_path: string)
---@field report_error fun(error_message: string)
---@field show_logs fun(file_paths: table)
---@field show_all_devices fun(devices: device, on_user_pick: fun(index: integer))
---@field get_selected_device fun():device
---@field is_device_chosen fun():boolean
---@field build_command_executor fun(config: config)?
---@field create_log_file_name (fun():string)

---@class config
Config = {
   project_type   = ProjectType.UNDEFINED,
   project_path   = "",
   configuration  = ConfigurationType.DEBUG,
   ---@type device?
   device         = nil,
   sdk            = nil,
   scheme         = "",
}

---@class configs
Configs = {
   build  = { Config },
   run    = { Config },
   custom = {
      {
         ---@type string?
         name=nil,
         ---@type string?
         command=nil,
      },
   }
}
