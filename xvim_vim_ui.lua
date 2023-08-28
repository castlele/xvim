UI = {}

function UI.open_file_in_split_window(file_path)
    vim.cmd("split")
    vim.cmd("edit " .. file_path)
end

return UI
