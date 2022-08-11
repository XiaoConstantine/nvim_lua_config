local auto_run = {}

auto_run.attach_to_buffer = function(output_bufnr, pattern, command)
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("my-auto-run", { clear = true }),
        pattern = pattern,
        callback = function()
            local append_data = function(_, data)
                if data then
                    vim.api.nvim_buf_set_lines(output_bufnr, -1, -1, false, data)
                end
            end

            vim.api.nvim_buf_set_lines(output_bufnr, 0, -1, false, { "Output:" })
            vim.fn.jobstart(command, {
                stdout_buffered = true,
                on_stdout = append_data,
                on_stderr = append_data,
            })
        end,
    })
end


auto_run.create_split_buf = function(width)
    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.cmd(("belowright vertical sbuffer " .. bufnr))
    local winnr = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_width(winnr, width)
    return bufnr
end


auto_run.default_cmd = function(filetype, mode)
    local cmd
    if filetype == "python" then
        cmd = "python3"
        if mode == "test" then
            cmd = cmd .. " -m pytest "
        end
    elseif filetype == "go" then
        cmd = "go"
        if mode == "test" then
            cmd = cmd .. " test "
        end
    elseif filetype == "zig" then
        if mode == "test" then
            cmd = "zig test "
        elseif mode == "format" then
            cmd = "zig fmt "
        else
            cmd = "zig run "
        end
    elseif filetype == "lua" then
        cmd = "luamake"
        if mode == "test" then
            cmd = cmd .. " test"
        end
    end
    return cmd
end


vim.api.nvim_create_user_command("AutoRun", function()
    print "AutoRun starts now..."
    local filetype = vim.bo.filetype
    Path = vim.fn.input("Path: ", vim.api.nvim_buf_get_name(0))
    local mode = vim.fn.input "Mode: "
    local command = auto_run.default_cmd(filetype, mode) .. Path
    local pattern = vim.fn.input "Pattern: "
    -- turns out this is the cause of path not propagate properly
    local bufnr = auto_run.create_split_buf(50)

    auto_run.attach_to_buffer(tonumber(bufnr), pattern, command)
end, {})

return auto_run
