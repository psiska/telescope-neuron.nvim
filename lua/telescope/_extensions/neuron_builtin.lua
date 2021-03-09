local actions = require('telescope.actions')
--local action_state = require('telescope.actions.state')
local action_set = require('telescope.actions.set')
local conf = require('telescope.config').values
local entry_display = require('telescope.pickers.entry_display')
local mfinders = require('telescope.jfinders')
--local log = require('telescope.log')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local utils = require('telescope.utils')
local Path = require('plenary.path')
local os_sep = Path.path.sep

local json = require('telescope.json')

-- ## General functions

local function makeZettelDisplay(entry)
  local zettelTitleDisplayer = entry_display.create{
    separator = ' ',
    items = {
      {width = 15, right_justify = false}, -- ID
      {remaining = true, right_justify = true}  -- Title
    },
  }
  return zettelTitleDisplayer{
    {entry.id, 'ZettelId'},
    {entry.title, 'Title'}
  }
end

local function tableToZettel(neuron_db_path, entry)
  return {
    id = entry['ID'],
    ordinal = entry['ID'],
    filePath = entry['Path'],
    cwd = neuron_db_path,
    path = neuron_db_path .. os_sep .. entry['Path'],
    slug = entry['Slug'],
    title = entry['Title'],
    date = entry['Date'][0],
    time = entry['Date'][1],
    display = makeZettelDisplay
  }
end

local M = {}
local function gen_from_neuron_backlinks(opts)
  return function(line)
    local result = {}
    local t = string.sub(line, 1, 1)
    -- Filter out non json lines
    if t ~= '[' and t ~= '{' then
      return {}
    end
    local pJson = json.decode(line)
    --print("juu: "..vim.inspect(line))
    for _, v in ipairs(pJson['result']) do
      table.insert(result, tableToZettel(opts.neuron_db_path, v[2]))
    end
    return result
  end
end

local function gen_from_neuron_all_notes(opts)
  return function(line)
    local result = {}
    local t = string.sub(line, 1, 1)
    -- Filter out non json lines
    if t ~= '[' and t ~= '{' then
      return {}
    end
    local pJson = json.decode(line)
    --print("juu: "..vim.inspect(line))
    for _, v in ipairs(pJson) do
      table.insert(result, tableToZettel(opts.neuron_db_path, v))
    end
    return result
  end
 end

M.backlinks = function(opts)
  opts = opts or {}
  opts.neuron_db_path = opts.neuron_db_path or vim.fn.expand('~/Sync/neuron')
  opts.cwd = opts.neuron_db_path
  opts.bin = opts.bin and vim.fn.expand(opts.bin) or vim.fn.exepath('neuron')
  opts.entries_maker = utils.get_lazy_default(opts.entries_maker, gen_from_neuron_backlinks, opts)

  local currentZettelId = vim.fn.fnamemodify(vim.fn.expand("%s"),":t:r")
  if currentZettelId ~= nil then
    pickers.new(opts,{
      prompt_title = 'All Backlinks',
      finder = mfinders.new_multi_entries_oneshot_job(
        { opts.bin, '-d', opts.neuron_db_path, 'query', '--backlinks-of', currentZettelId },
        opts
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
    finder = mfinders.new_multi_entries_job(function(_)
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
