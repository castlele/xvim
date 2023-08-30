local xvim_conf_file_name = "./xvim.json"
local build_dir_path = "./.build"
local logs_dir_path = "./.build/logs/"

---@class settings
local settings = {
   xvim_config_file_name = xvim_conf_file_name,
   build_directory_path  = build_dir_path,
   logs_directory_path   = logs_dir_path,
}

return settings
