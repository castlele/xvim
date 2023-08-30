require("cluautils.table_utils")

---@param title string
---@param lines table
---@param is_open boolean?
local function set_quick_fix(title, lines, is_open)
    vim.fn.setqflist({}, "a", {title = title, lines = lines})

    is_open = is_open or false

    if is_open then
        vim.cmd(":copen")
    end
end

local function clear_quick_fix()
    vim.fn.setqflist({})
end

UI = {}

---@param file_path string
function UI.open_file_in_split_window(file_path)
    vim.cmd("split")
    vim.cmd("edit " .. file_path)
end

---@param file_paths table
function UI.show_logs_quick_fix_window(file_paths)
    local quick_fix_lines = table.map(file_paths, function (path) return path .. ":1:1" end)

    clear_quick_fix()
    set_quick_fix("Logs", quick_fix_lines, true)
end

return UI
