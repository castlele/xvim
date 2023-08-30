require("cluautils.string_utils")
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

---@param device device
---@return string
local function parse_device_to_line(device)
        local name = device.name or ""
        local udid = device.udid or ""
        local state = device.state or ""
        local os_name = device.os or ""

        return table.concat({name, udid, state, os_name}, "-")
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

---@param devices devices
---@param on_user_pick fun(index: integer)
function UI.show_all_devices(devices, on_user_pick)
    local lines = {}

    for _, device in pairs(devices.physical) do
        table.insert(lines, parse_device_to_line(device))
    end

    for _, device in pairs(devices.simulators) do
        table.insert(lines, parse_device_to_line(device))
    end

    vim.cmd("split")

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(true, true)

    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_buf_set_lines(0, 1, #lines, false, lines)

    vim.api.nvim_buf_set_keymap(0, "n", "<CR>", "", {
        callback=function ()
            local index = vim.api.nvim_win_get_cursor(0)[1]

            if index > 1 then
                index = index - 1
            end

            on_user_pick(index)
        end
    })
end

return UI
