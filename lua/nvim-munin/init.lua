-- autocmd on directory open? to sync repo
-- autocmd on file write to update repo
-- command to search by text
-- command to search by tag
-- command to search by category
-- command to list tags
-- picker to insert tag
-- picker to link to other note
-- command to navigate link

print(":lua/nvim-munin/init.lua")

local munin = require("munin.repo")
local utils = require("munin.utils")

local M = {
    config = {
        autoSync = false,
        extensions = { "md" }
    }
}

local function init()
    local cwd = vim.loop.cwd()
    print("cwd = "..cwd)

    print("Initializing repo")
    local repo = munin.init(cwd)

    if repo.exists() then
        print("Found repo at "..repo._config_path)
        return repo
    end
end

local function buffer_entered(event)
    print(string.format("event fired: %s", vim.inspect(event)))
    if M.repo then
        local parsed_path = utils.parse_file_path(event.file, M.repo._path)
        local note = M.repo.get_note(parsed_path.path)
        if note then
            print(string.format("Opened note titled %s", note.title))
        end
    end
end

local function buffer_write(event)
    print(string.format("event fired: %s", vim.inspect(event)))
    if M.repo then
        local buffer_lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
        local content = table.concat(buffer_lines, "\n")
        local parsed_path = utils.parse_file_path(event.file, M.repo._path)
        print(vim.inspect(parsed_path))
        local note, err = M.repo.save_note(parsed_path.title, content, parsed_path.category)
        if err then
            vim.notify(err, vim.log.levels.ERROR)
        end
        if note then
            print(string.format("Saved note titled %s", note.title))
        end
    end
end

local function directory_changed(event)
    print(string.format("event fired: %s", vim.inspect(event)))
    M.repo = init()
end

function M.setup(config)
    if config then M.config = config end

    M.repo = init()

    local group = vim.api.nvim_create_augroup("munin.nvim", {})

    vim.api.nvim_create_autocmd({"DirChanged"}, {
        group = group,
        callback = directory_changed
    })

    vim.api.nvim_create_autocmd({"BufEnter"}, {
        group = group,
        pattern = {"*.md"},
        callback = buffer_entered
    })

    vim.api.nvim_create_autocmd({"BufWrite"}, {
        group = group,
        pattern = {"*.md"},
        callback = buffer_write
    })
end

return M
