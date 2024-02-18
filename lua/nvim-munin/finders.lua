local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values

local munin_utils = require("munin.utils")

local M = {}

M.find_notes_by_tag = function(notes, context, opts)
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "tag: "..context.tag,
    finder = finders.new_table {
      results = notes,
      entry_maker = function(entry)
        local file_path = munin_utils.get_absolute_path(entry.path, context.repo._path)
        return {
          value = entry,
          display = entry.path,
          ordinal = entry.path,
          path = file_path,
        }
      end
    },
    previewer = conf.file_previewer(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

return M
