local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local action_set = require('telescope.actions.set')
local conf = require('telescope.config').values
local entry_display = require('telescope.pickers.entry_display')
local mfinders = require('telescope.mfinders')
local log = require('telescope.log')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local utils = require('telescope.utils')
local Path = require('plenary.path')
local os_sep = Path.path.sep

local json = require('telescope.json')

local M = {}
local function gen_from_neuron_all_notes(opts)
  local displayer = entry_display.create{
    separator = ' ',
    items = {
      {width = 15, right_justify = false}, -- ID
      {remaining = true, right_justify = true}  -- Title
    },
  }

  local function make_display(entry)
    return displayer{
      {entry.id, 'ZettelId'},
      {entry.title, 'Title'}
    }
  end

  return function(line)
    local result = {}
    local t = string.sub(line,1,1)
    if t ~= '[' then
      return {}
    end
    local pJson = json.decode(line)
    for _, v in ipairs(pJson) do
      local obj = {
        id = v['ID'],
        ordinal = v['ID'],
        filePath = v['Path'],
        cwd = opts.neuron_db_path,
        path = opts.neuron_db_path .. os_sep .. v['Path'],
        --path = v['Path'],
        slug = v['Slug'],
        title = v['Title'],
        date = v['Date'][0],
        time = v['Date'][1],
        display = make_display
      }
      table.insert(result, obj)
    end
    return result
  end
end

M.list = function(opts)
  opts = opts or {}
  opts.neuron_db_path = opts.neuron_db_path or vim.fn.expand('~/Sync/neuron')
  opts.cwd = opts.neuron_db_path
  opts.bin = opts.bin and vim.fn.expand(opts.bin) or vim.fn.exepath('neuron')
  opts.entries_maker = utils.get_lazy_default(opts.entries_maker, gen_from_neuron_all_notes, opts)

  --A Sorter is called by the Picker on each item returned by the Finder. It return a number, which is equivalent to the "distance" between the current prompt and the entry returned by a finder.
  pickers.new(opts, {
    prompt_title = 'All Zettels',
    finder = mfinders.new_multi_entries_job(function(prompt)
      --if not prompt or string.len(prompt) < 3 then
      --  return nil
      --end
      return { opts.bin, '-d', opts.neuron_db_path, 'query', '--zettels'}
      end,
      opts.entries_maker
      ),
    sorter = conf.file_sorter(opts),
    previewer = previewers.vim_buffer_cat.new(opts),
    attach_mappings = function(prompt_bufnr)
      action_set.select:replace(function(_, type)
        local entry = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.cmd(':e '..entry.path)
      end)
      return true
    end,
  }):find()
end

return M
