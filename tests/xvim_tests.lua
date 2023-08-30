require("cluautils.tests.base_test_case")
require("cluautils.file_manager")
require("cluautils.table_utils")
require("cluautils.json")
require("lua.xvim.xvim")
require("lua.xvim.models")

---@MARK - Constants

local config_file_path = "./xvim.json"
local project_file_path = "./xvim.xcodeproj"
local build_dir_path = "./build"
local build_logs_dir_path = "./build/logs/"

---@MARK - Helper methods

---@TODO: create common module with helpers for tests
local function create_directories(dirs)
    for _, dir in pairs(dirs) do
        os.execute("mkdir " .. dir)
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
    local default_config = Json.encode(Config)

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

        ]] .. Json.encode(Config)
    end)

    local result = ReadConfig(config_file_path)

    delete_files({config_file_path})
    return result ~= nil and table.is_equal(result, Config)
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

    local build_settings = ReadConfig(config_file_path)

    return build_settings == nil
end

function XvimTests:test_get_build_settings_from_empty_file()
    delete_files({config_file_path})
    create_files({config_file_path})

    local build_settings = ReadConfig(config_file_path)

    return build_settings == nil
end

function XvimTests:test_get_build_settings_from_file_with_invalid_json()
    FM.write_to_file(config_file_path, IOMODE.OVERRIDE, function ()
        return '"string_field": "hello world"}' -- No start openning bracket '{'
    end)

    local build_settings = ReadConfig(config_file_path)

    delete_files({config_file_path})
    return build_settings == nil
end

function XvimTests:test_get_build_settings_from_file_with_invalid_config()
    FM.write_to_file(config_file_path, IOMODE.OVERRIDE, function ()
        return '{"string_field": "hello world"}'
    end)

    local build_settings = ReadConfig(config_file_path)

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

    local build_settings = ReadConfig(config_file_path)

    delete_files({config_file_path})
    return build_settings ~= nil and table.is_equal(build_settings, config)
end

---@MARK - Get logs files paths

function XvimTests:test_if_logs_directory_does_not_exists_returns_empty_table()
    delete_files({build_logs_dir_path, build_dir_path})

    local log_files = GetLogFilesPaths()

    return #log_files == 0
end

function XvimTests:test_if_logs_directory_is_empty_returns_empty_table()
    create_directories({build_dir_path, build_logs_dir_path})

    local log_files = GetLogFilesPaths()

    delete_files({build_logs_dir_path, build_dir_path})
    return #log_files == 0
end

function XvimTests:test_returns_every_log_files()
    local log_file_new = build_logs_dir_path .. "21:34_29.08.2023.log"
    local log_file_old = build_logs_dir_path .. "21:34_29.08.20222.log"
    create_directories({build_dir_path, build_logs_dir_path})
    create_files({log_file_new, log_file_old})

    local log_files = GetLogFilesPaths()

    delete_files({log_file_new, log_file_old, build_logs_dir_path, build_dir_path})
    return #log_files == 2
end

function XvimTests:test_if_log_directory_contains_other_files_returns_only_log_files()
    local log_file_new = build_logs_dir_path .. "21:34_29.08.2023.log"
    local log_file_old = build_logs_dir_path .. "21:34_29.08.20222.log"
    local other_file = build_logs_dir_path .. "some_random_file.txt"
    create_directories({build_dir_path, build_logs_dir_path})
    create_files({log_file_new, log_file_old, other_file})

    local log_files = GetLogFilesPaths()

    delete_files({other_file, log_file_new, log_file_old, build_logs_dir_path, build_dir_path})
    return #log_files == 2
end

XvimTests:run_tests()
