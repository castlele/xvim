require("cluautils.tests.base_test_case")
require("cluautils.file_manager")
require("cluautils.table_utils")
require("cluautils.json")
require("xvim")

---@MARK - Constants

local config_file_path = "./xvim.json"
local project_file_path = "./xvim.xcodeproj"
local workspace_file_path = "./xvim.xcworkspace"
local build_dir_path = "./build"
local build_logs_dir_path = "./build/logs/"

---@MARK - Helper methods

local function create_directories(dirs)
    for _, dir in pairs(dirs) do
        os.execute("mkdir " .. dir)
    end
end

local function delete_directories(dirs)
    for _, dir in pairs(dirs) do
        os.execute("rm -rf " .. dir)
    end
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

---@MARK - Tests

XvimTests = CTestCase

---@MARK - CreateBuildSettingsFileIfNeeded tests

function XvimTests:test_creat_build_settings_with_no_files()
    delete_files({config_file_path, project_file_path})
    local expected_error_message = XvimError.NO_PROJECT

    local output = CreateBuildSettingsFileIfNeeded()

    return output == expected_error_message
end

function XvimTests:test_create_build_settings_with_no_project_file()
    delete_files({project_file_path})
    FM.create_file(config_file_path)
    local expected_error_message = XvimError.NO_PROJECT

    local output = CreateBuildSettingsFileIfNeeded()

    FM.delete_file(config_file_path)
    return output == expected_error_message
end

function XvimTests:test_create_build_settings_with_no_config_file()
    delete_files({config_file_path, project_file_path})
    FM.create_file(project_file_path)
    local default_config = Json.encode(DefaultConfig())

    CreateBuildSettingsFileIfNeeded()
    local config_file = io.open(config_file_path)
    local content = table.concat(FM.get_lines_from_file(config_file), "\n")

    if config_file ~= nil then
        config_file:close()
    end

    local saved_config = Json.encode(Json.decode(content))

    delete_files({config_file_path, project_file_path})
    return saved_config == default_config
end

function XvimTests:test_create_build_settings_with_all_files()
    create_files({config_file_path, project_file_path})
    FM.write_to_file(config_file_path, IOMODE.OVERRIDE, function ()
        return "{}"
    end)

    CreateBuildSettingsFileIfNeeded()
    local config_file = io.open(config_file_path)
    local content = FM.get_lines_from_file(config_file)

    if config_file ~= nil then
        config_file:close()
    end

    delete_files({config_file_path, project_file_path})
    return #content == 1 and content[1] == "{}"

end

---@MARK - ReadConfig tests

function XvimTests:test_read_config_with_one_comment()
    create_files({config_file_path})
    FM.write_to_file(config_file_path, IOMODE.OVERRIDE, function ()
        return "//some random comment"
    end)

    local result = ReadConfig(config_file_path)

    delete_files({config_file_path})
    return result == nil
end

function XvimTests:test_read_config_with_saved_config_and_comment_on_top()
    create_files({config_file_path})
    FM.write_to_file(config_file_path, IOMODE.OVERRIDE, function ()
        return [[
        //some random comment

        ]] .. Json.encode(DefaultConfig())
    end)

    local result = ReadConfig(config_file_path)

    delete_files({config_file_path})
    return result ~= nil and table.is_equal(result, DefaultConfig())
end

---@MARK - EditConfig tests

function XvimTests:test_edit_config()
    ---@type string
    local opened_file
    ---@type environment
    local mock_env = {
        open_file = function (file_path)
            opened_file = file_path
        end
    }

    EditConfig(mock_env)

    return opened_file == "./xvim.json"
end

---@MARK - GetBuildSettings tests

function XvimTests:test_get_build_settings_from_non_existing_file()
    delete_files({config_file_path})

    local build_settings = GetBuildSettings()

    return build_settings == nil
end

function XvimTests:test_get_build_settings_from_empty_file()
    delete_files({config_file_path})
    create_files({config_file_path})

    local build_settings = GetBuildSettings()

    return build_settings == nil
end

function XvimTests:test_get_build_settings_from_file_with_invalid_json()
    FM.write_to_file(config_file_path, IOMODE.OVERRIDE, function ()
        return '"string_field": "hello world"}' -- No start openning bracket '{'
    end)

    local build_settings = GetBuildSettings()

    delete_files({config_file_path})
    return build_settings == nil
end

function XvimTests:test_get_build_settings_from_file_with_invalid_config()
    FM.write_to_file(config_file_path, IOMODE.OVERRIDE, function ()
        return '{"string_field": "hello world"}'
    end)

    local build_settings = GetBuildSettings()

    delete_files({config_file_path})
    return build_settings == nil
end

function XvimTests:test_get_build_settings_from_file_with_valid_config()
    ---@type config
    local config = {
        project_path="some_path",
        project_type=ProjectType.PROJECT,
        configuration=ConfigurationType.RELEASE,
        scheme="Some_scheme"
    }
    FM.write_to_file(config_file_path, IOMODE.OVERRIDE, function ()
        return Json.encode(config, {indent="    ", pretty=true})
    end)

    local build_settings = GetBuildSettings()

    delete_files({config_file_path})
    return build_settings ~= nil and table.is_equal(build_settings, config)
end

---@MARK - CreateBuildCommand

function XvimTests:test_create_build_command_project()
    --[[
    -- xcodebuild -project xvim.xcodeproj -scheme xvim -configuration Debug -sdk iphonesimulator16.4
    --]]
    local expected_command = "xcodebuild -project " .. project_file_path .. " -configuration Debug -scheme xvim -sdk iphonesimulator16.4"
    ---@type config
    local config = get_config(project_file_path, ProjectType.PROJECT)

    local command = CreateBuildCommand(config)

    return command == expected_command
end

---@MARK - Creation of build command tests

function XvimTests:test_create_build_command_workspace()
    --[[
    -- xcodebuild -workspace xvim.xcworkspace -scheme xvim -configuration Debug -sdk iphonesimulator16.4
    --]]
    local expected_command = "xcodebuild -workspace " .. workspace_file_path ..  " -configuration Debug -scheme xvim -sdk iphonesimulator16.4"
    ---@type config
    local config = get_config(workspace_file_path, ProjectType.WORKSPACE)

    local command = CreateBuildCommand(config)

    return command == expected_command
end

---@MARK - Build tests

function XvimTests:test_run_build_first_time_creates_build_directory_with_build_log_file()
    delete_files({build_dir_path, build_logs_dir_path})
    local config = get_config(workspace_file_path, ProjectType.WORKSPACE)
    local is_log_dir_exists = false
    local is_build_dir_exists = false
    local is_build_log_created = false
    local completion = function (_)
        local files = FM.get_dir_content({dir_path=build_logs_dir_path})
        print(vim.inspect(files))
        is_log_dir_exists = FM.is_file_exists(build_logs_dir_path)
        is_build_dir_exists = FM.is_file_exists(build_dir_path)
        is_build_log_created = #files >= 1

        delete_files(table.concat_tables(files, {build_logs_dir_path, build_dir_path}))
    end

    Build(config, nil, completion)

    return is_log_dir_exists and is_build_dir_exists and is_build_log_created
end

function XvimTests:test_run_build_command_creates_build_log_file_inside_build_directory()
    local existing_log_file = build_logs_dir_path .. "20:58_28.08.2023.log"
    create_directories({build_dir_path, build_logs_dir_path, })
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

    Build(config, nil, completion)

    return is_old_log_exists and is_new_log_created
end

XvimTests:run_tests()
