local logger = {}

---@return string|osdate
logger.create_log_file_name = function()
   return os.date("%H:%M_%d.%m.%Y")
end

return logger
