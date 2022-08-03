local attach_to_buffer = function(output_bufnr, pattern, command)
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("my-auto-run", {clear = true}),
        pattern = pattern,
        callback = function()
            local append_data = function(_, data)
                if data then
                    vim.api.nvim_buf_set_lines(output_bufnr, -1, -1, false, data)
                end
            end

        vim.api.nvim_buf_set_lines(output_bufnr, 0, -1, false, {"Output:"})
        vim.fn.jobstart(command, {
            stdout_buffered = true,
            on_stdout = append_data,
            on_stderr = append_data,
        })
       end,
    })
end


local create_split_buf = function(width)
    local bufnr = vim.api.nvim_create_buf(true, true)
    vim.cmd(("belowright vertical sbuffer " .. bufnr))
    local winnr = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_width(winnr, width)
    return bufnr
end


local default_cmd = function(filetype, mode, path)
    local cmd
    print(filetype, mode)
    if filetype == "python" then
        cmd = "python"
        if mode == "test" then
            cmd = cmd .. " -m pytest"
        end
        if path then
            cmd = cmd .. " " ..path
        end
    elseif filetype == "go" then
        cmd = "go"
        if mode == "test" then
            cmd = cmd .. " test"
        end
        if path then
            cmd = cmd .. " " .. path
        end
    elseif filetype == "zig" then
        cmd = "zig"
        if mode == "test" then
            cmd = cmd .. " test"
        end
        if path then
            cmd = cmd .. " " .. path
        end
    end
    return cmd
end


vim.api.nvim_create_user_command("AutoRun", function()
    print "AutoRun starts now..."
    print(vim.api.nvim_buf_get_name(0))
    local filetype = vim.bo.filetype
    local bufnr = create_split_buf(50)
    --[[
       [local command = vim.split(vim.fn.input "Command: ", " ")
       ]]
    local path = vim.fn.input "Path: "
    local mode = vim.fn.input "Mode: "
    local command = default_cmd(filetype, mode, path)
    print(command)
    local pattern = vim.fn.input "Pattern: "
    attach_to_buffer(tonumber(bufnr), pattern, command)
end, {})
