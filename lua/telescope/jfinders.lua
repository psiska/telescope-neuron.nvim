local Job = require('plenary.job')
local log = require('telescope.log')

local finders = {}

local _callable_obj = function()
  local obj = {}

  obj.__index = obj
  obj.__call = function(t, ...) return t:_find(...) end

  obj.close = function() end

  return obj
end

--[[ =============================================================

    JobMultiFinder

Uses an external Job to get results. Processes results as they arrive.
Support for creating more results from single entry.
Ideal for json input from external program.

For more information about how Jobs are implemented, checkout 'plenary.job'

-- ============================================================= ]]
local JobMultiFinder = _callable_obj()

--- Create a new finder command
---
---@param opts table Keys:
--     fn_command function The function to call
--
function JobMultiFinder:new(opts)
  opts = opts or {}

  assert(opts.entries_maker, "`entries_maker` should be provided for finder:new")

  local obj = setmetatable({
    entries_maker = opts.entries_maker,
    fn_command = opts.fn_command,
    cwd = opts.cwd,
    writer = opts.writer,

    -- Maximum number of results to process.
    --  Particularly useful for live updating large queries.
    maximum_results = opts.maximum_results,
  }, self)

  return obj
end

function JobMultiFinder:_find(prompt, process_result, process_complete)
  log.trace("Finding...")

  if self.job and not self.job.is_shutdown then
    log.debug("Shutting down old job")
    self.job:shutdown()
  end

  local on_output = function(_, line, _)
    if not line or line == "" then
      return
    end

    local entries = self.entries_maker(line)
    for _, i in ipairs (entries) do
      log.debug("processing_result: "..vim.inspect(i))
      process_result(i)
    end

    --process_result(line)
  end

  local opts = self:fn_command(prompt)
  if not opts then return end

  local writer = nil
  if opts.writer and Job.is_job(opts.writer) then
    writer = opts.writer
  elseif opts.writer then
    writer = Job:new(opts.writer)
  end

  self.job = Job:new {
    command = opts.command,
    args = opts.args,
    cwd = opts.cwd or self.cwd,

    maximum_results = self.maximum_results,

    writer = writer,

    enable_recording = false,

    on_stdout = on_output,
    on_stderr = on_output,

    on_exit = function()
      process_complete()
    end,
  }

  self.job:start()
end

-- local
--
---@param command_generator function (string): String Command list to execute.
---@param entries_maker function(line: string) => table
---         @key cwd string
finders.new_multi_entries_job = function(command_generator, entries_maker, maximum_results, cwd)
  return JobMultiFinder:new {
    fn_command = function(_, prompt)
      local command_list = command_generator(prompt)
      if command_list == nil then
        return nil
      end

      local command = table.remove(command_list, 1)

      return {
        command = command,
        args = command_list,
      }
    end,

    entries_maker = entries_maker,
    maximum_results = maximum_results,
    cwd = cwd,
  }
end


local OneshotJobMultiFinder = _callable_obj()

function OneshotJobMultiFinder:new(opts)
  opts = opts or {}

  assert(opts.entries_maker, "`entries_maker` should be provided for oneshotJobMultiFinder:new")
  assert(not opts.results, "`results` should be used with finder.new_table")
  assert(not opts.static, "`static` should be used with finder.new_oneshot_job")

  local obj = setmetatable({
    entries_maker = opts.entries_maker,
    fn_command = opts.fn_command,

    cwd = opts.cwd,
    writer = opts.writer,

    maximum_results = opts.maximum_results,

    _started = false,
  }, self)

  obj._find = coroutine.wrap(function(finder, _, process_result, process_complete)
    local num_execution = 1
    local num_results = 0

    local results = setmetatable({}, {
      __newindex = function(t, k, v)
        rawset(t, k, v)
        process_result(v)
      end
    })

    local job_opts = finder:fn_command(_)
    if not job_opts then
      error(debug.traceback("expected `job_opts` from fn_command"))
    end

    local writer = nil
    if job_opts.writer and Job.is_job(job_opts.writer) then
      writer = job_opts.writer
    elseif job_opts.writer then
      writer = Job:new(job_opts.writer)
    end

    local on_output = function(_, line)
      -- This will call the metamethod, process_result
      local entries = finder.entries_maker(line)
      for _, i in ipairs(entries) do
        num_results = num_results + 1
        results[num_results] = i
      end
      --num_results = num_results + 1
      --results[num_results] = finder.entry_maker(line)
    end

    local completed = false
    local job = Job:new {
      command = job_opts.command,
      args = job_opts.args,
      cwd = job_opts.cwd or finder.cwd,

      maximum_results = finder.maximum_results,

      writer = writer,

      enable_recording = false,

      on_stdout = on_output,
      on_stderr = on_output,

      on_exit = function()
        process_complete()
        completed = true
      end,
    }

    job:start()

    while true do
      finder, _, process_result, process_complete = coroutine.yield()
      num_execution = num_execution + 1

      local current_count = num_results
      for index = 1, current_count do
        process_result(results[index])
      end

      if completed then
        process_complete()
      end
    end
  end)

  return obj
end

function OneshotJobMultiFinder:old_find(_, process_result, process_complete)
  local first_run = false

  if not self._started then
    first_run = true

    self._started = true

  end

  -- First time we get called, start on up that job.
  -- Every time after that, just use the results LUL
  if not first_run then
    return
  end
end


---@param command_list string[] Command list to execute.
---@param opts table
---         @key entries_maker function: function(line: string) => table
---         @key cwd string
finders.new_multi_entries_oneshot_job = function(command_list, opts)
  opts = opts or {}

  command_list = vim.deepcopy(command_list)

  local command = table.remove(command_list, 1)

  return OneshotJobMultiFinder:new {
    entries_maker = opts.entries_maker,

    cwd = opts.cwd,
    maximum_results = opts.maximum_results,

    fn_command = function()
      return {
        command = command,
        args = command_list,
      }
    end,
  }
end

return finders
