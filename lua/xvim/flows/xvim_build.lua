require("xvim.models")
local settings = require("xvim.settings")

---@MARK - Helpers

---@param path string
local function create_directory(path)
   os.execute("mkdir " .. path)
end

---@MARK - API

---@param config config
---@param commands table?
---@return string
function CreateXcodeBuildCommand(config, commands)
   local cmd = table.concat_tables({"xcodebuild"}, commands or {})

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

   table.insert(cmd, "-jobs 4")

   table.insert(cmd, "-derivedDataPath " .. settings.build_directory_path)

   return table.concat(cmd, " ")
end

---@param config config
---@param build_command string?
---@param environment environment
---@param completion fun()?
function Build(config, build_command, environment, completion)
   if not FM.is_file_exists(settings.build_directory_path) then
      create_directory(settings.build_directory_path)
   end

   if not FM.is_file_exists(settings.logs_directory_path) then
      create_directory(settings.logs_directory_path)
   end

   local log_file_name = environment.create_log_file_name()
   local log_file_path = settings.logs_directory_path .. log_file_name .. ".log"
   local executor = environment.build_command_executor

   executor = executor or function (_)
      build_command = build_command or CreateXcodeBuildCommand(config)
      local full_command = build_command .. " | xcpretty -r json-compilation-database --output compile_commands.json".. " > " .. log_file_path
      -- local full_command = build_command .. " > " .. log_file_path

      io.popen(full_command)
   end

   executor(config)

   if completion ~= nil then completion() end
end
