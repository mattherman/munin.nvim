-- command to search by text
-- command to search by tag
-- command to search by category
-- command to list tags
-- picker to insert tag
-- picker to link to other note
-- command to navigate link

local log = require("nvim-munin.log")
require("munin.logger").configure(log)

local munin = require("munin.repo")
local utils = require("munin.utils")

local finders = require("nvim-munin.finders")

local M = {
    config = {
        autoSync = false,
        patterns = { "*.md" }
    }
}

local function merge_config_with_default(config)
    for k, v in pairs(config) do
        M.config[k] = v
    end
end

local function init()
    local cwd = vim.loop.cwd()

    log.fmt_trace("Initializing repo: %s", cwd)
    local repo = munin.init(cwd)

    if repo.exists() then
        log.trace("Found repo at "..repo._config_path)

        if M.config.autoSync then
            log.trace("Auto sync enabled, indexing repo...")
            local index_err = require("munin.indexer").index(repo)
            if index_err then
                log.fmt_error("Failed to index repo (%s): %s", repo._path, index_err)
                vim.notify("Failed to sync munin database")
            else
                vim.notify("Munin database synced")
            end
        end

        return repo
    end
end

local function buffer_entered(event)
    log.fmt_trace("event fired: %s", vim.inspect(event))
    if M.repo then
        local parsed_path = utils.parse_file_path(event.file, M.repo._path)
        local note = M.repo.get_note(parsed_path.path)
        if note then
            log.fmt_trace("Opened note titled %s", note.title)
        end
    end
end

local function buffer_write(event)
    log.fmt_trace("event fired: %s", vim.inspect(event))
    if M.repo then
        local buffer_lines = vim.api.nvim_buf_get_lines(0, 0, vim.api.nvim_buf_line_count(0), false)
        local content = table.concat(buffer_lines, "\n")
        local parsed_path = utils.parse_file_path(event.file, M.repo._path)
        log.fmt_trace("Saving note buffer for file: %s", vim.inspect(parsed_path))
        local note, err = M.repo.save_note(parsed_path.title, content, parsed_path.category)
        if err then
            log.error(err, vim.log.levels.ERROR)
        end
        if note then
            log.fmt_trace("Saved note titled %s", note.title)
        end
    end
end

local function directory_changed(event)
    log.fmt_trace("event fired: %s", vim.inspect(event))
    M.repo = init()
end

function M.setup(config)
    if config then merge_config_with_default(config) end

    M.repo = init()

    local group = vim.api.nvim_create_augroup("munin.nvim", {})

    vim.api.nvim_create_autocmd({"DirChanged"}, {
        group = group,
        callback = directory_changed
    })

    vim.api.nvim_create_autocmd({"BufEnter"}, {
        group = group,
        pattern = M.config.patterns,
        callback = buffer_entered
    })

    vim.api.nvim_create_autocmd({"BufWrite"}, {
        group = group,
        pattern = M.config.patterns,
        callback = buffer_write
    })
end

local function find_tag_under_cursor(line, cursor_pos)
    local first, last = 0, 0
    while true do
        first, last = line:find("@([^%s]+)", first+1)
        if not first then break end
        if cursor_pos >= first and cursor_pos <= last then
            return line:sub(first + 1, last) -- Omit the '@'
        end
    end
end

function M.search_tag_under_cursor()
    local r, c = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_buf_get_lines(0, r-1, r, false)[1]
    local tag = find_tag_under_cursor(line, c + 1)
    if not tag then
        log.trace("No tag found")
        return
    end
    log.trace("Searching tag: "..tag)
    local notes, err = M.repo.get_notes_by_tag(tag)
    if notes then
        local message = string.format("Found %d notes matching tag", #notes)
        log.trace(message)
        finders.find_notes_by_tag(notes, { tag = tag, repo = M.repo })
    else
        log.error(err)
    end
end

return M
