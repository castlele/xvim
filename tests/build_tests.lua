require("cluautils.tests.base_test_case")
require("lua.xvim.flows.xvim_build")

---@MARK - Constants

local build_dir_path = "./build"
local build_logs_dir_path = "./build/logs/"
local workspace_file_path = "./xvim.xcworkspace"
local project_file_path = "./xvim.xcodeproj"
local mock_env = {
    create_log_file_name=function () return "log_file_name.log" end
}

---@MARK - Helpers

local function create_directories(dirs)
   for _, dir in pairs(dirs) do
      os.execute("mkdir " .. dir)
   end
end

---@param path string
---@param project_type ProjectType
---@return config
local function get_config(path, project_type)
   return {
      project_path=path,
      project_type=project_type,
      configuration=ConfigurationType.DEBUG,
      sdk="iphonesimulator16.4",
      scheme="xvim",
   }
end

local function delete_files(files)
   for _, file in pairs(files) do
      FM.delete_file(file)
   end
end

local function create_files(files)
   for _, file in pairs(files) do
      FM.create_file(file)
   end
end

---@MARK - Tests

BuildTests = CTestCase

---@MARK - CreateXcodeBuildCommand

function BuildTests:test_create_build_command_project()
   --[[
   -- xcodebuild -project xvim.xcodeproj -scheme xvim -configuration Debug -sdk iphonesimulator16.4 -derivedDataPath ./build
   --]]
   local expected_command = "xcodebuild -project " .. project_file_path .. " -configuration Debug -scheme xvim -sdk iphonesimulator16.4 -derivedDataPath ./build"
   ---@type config
   local config = get_config(project_file_path, ProjectType.PROJECT)

   local command = CreateXcodeBuildCommand(config)

   return command == expected_command
end

---@MARK - Creation of build command tests

function BuildTests:test_create_build_command_workspace()
   --[[
   -- xcodebuild -workspace xvim.xcworkspace -scheme xvim -configuration Debug -sdk iphonesimulator16.4 -derivedDataPath ./build
   --]]
   local expected_command = "xcodebuild -workspace " .. workspace_file_path ..  " -configuration Debug -scheme xvim -sdk iphonesimulator16.4 -derivedDataPath ./build"
   ---@type config
   local config = get_config(workspace_file_path, ProjectType.WORKSPACE)

   local command = CreateXcodeBuildCommand(config)

   return command == expected_command
end

---@MARK - Build tests

function BuildTests:test_run_build_first_time_creates_build_directory_with_build_log_file()
   delete_files({build_dir_path, build_logs_dir_path})
   local config = get_config(workspace_file_path, ProjectType.WORKSPACE)
   local is_log_dir_exists = false
   local is_build_dir_exists = false
   local is_build_log_created = false
   local completion = function (_)
      local files = FM.get_dir_content({dir_path=build_logs_dir_path})
      is_log_dir_exists = FM.is_file_exists(build_logs_dir_path)
      is_build_dir_exists = FM.is_file_exists(build_dir_path)
      is_build_log_created = #files >= 1

      delete_files(table.concat_tables(files, {build_logs_dir_path, build_dir_path}))
    end

    Build(config, nil, mock_env, completion)

    return is_log_dir_exists and is_build_dir_exists and is_build_log_created
end

function BuildTests:test_run_build_command_creates_build_log_file_inside_build_directory()
   local existing_log_file = build_logs_dir_path .. "20:58_28.08.2023.log"
   create_directories({build_dir_path, build_logs_dir_path})
   create_files({existing_log_file})
   local config = get_config(workspace_file_path, ProjectType.WORKSPACE)
   local is_old_log_exists = false
   local is_new_log_created = false
   local completion = function (_)
      local files = FM.get_dir_content({dir_path=build_logs_dir_path})

      is_old_log_exists = FM.is_file_exists(existing_log_file)
      is_new_log_created = #files >= 2

      delete_files(table.concat_tables(files, {build_logs_dir_path, build_dir_path}))
   end

   Build(config, nil, mock_env, completion)

   return is_old_log_exists and is_new_log_created
end

BuildTests:run_tests()
