package.loaded['nvim-todoist.ui'] = nil
local vim = vim
local api = vim.api
local todoist_api = require('nvim-todoist.api')
local win_float_helpers = require('plenary.window.float')
local helpers = require('nvim-todoist.helpers')
local first = helpers.first
local ui = {}
ui.current_state =
  {
    api_key = os.getenv('TODOIST_API_KEY'),
    checked_task_start = '[x] ',
    checked_task_start_pat = '(%s*)%[x%]%s',
    task_start = '[ ] ',
    task_start_pat = '(%s*)%[%s%]%s',
    initialized = false,
    lines = {}
  }

local function assert_in_todoist()
  assert(api.nvim_buf_get_option(0, 'filetype') == 'todoist', 'Not in Todoist buffer')
end

local function render_task(task, padding)
  local padding = padding or ''
  local state = ui.current_state
  local task_ending = ''
  if task.due and task.due.date then
    task_ending = ' (' .. task.due.date .. ')'
  end
  local rendered
  if task.completed then
    rendered = padding .. state.checked_task_start .. task.content .. task_ending
  else
    rendered = padding .. state.task_start .. task.content .. task_ending
  end
  if task.children then
    local lines = {}
    table.insert(lines, rendered)
    for _, t in pairs(task.children) do
      table.insert(lines, render_task(t, padding .. '    '))
    end
    return vim.tbl_flatten(lines)
  else
    return rendered
  end
end

local function is_recurring_task(task)
  if task.due then
    -- TODO(smolck): Is the `or false` necessary? Only if `recurring` can be
    -- omitted when getting tasks from Todoist REST API.
    return task.due.recurring or false
  else
    return false
  end
end

local function centerish_string(str)
  local w = api.nvim_win_get_width(ui.current_state.win_id)
  return string.rep(' ', w / 2 - 10) .. str
end

local function create_buffer_lines()
  ui.current_state.lines = {}

  local daily_tasks_only = ui.current_state.daily_tasks_only or false
  local project_name = ui.current_state.project_name or 'Inbox'
  local state = ui.current_state
  local tasks = state.tasks
  local projects = state.projects
  local tree = {}
  for _, proj in ipairs(projects) do
    local filtered =
      vim.tbl_filter(
        function(x)
          return x.project_id == proj.id
        end,
        tasks
      )
    tree[proj.name] = filtered
  end
  local contents = {}
  if daily_tasks_only then
    table.insert(contents, centerish_string('Daily'))
    local processed = helpers.process_tasks(vim.tbl_filter(is_recurring_task, tasks))
    for _, t in pairs(processed) do
      ui.current_state.lines[#contents] = t

      local rendered = render_task(t)
      if type(rendered) == 'string' then
        table.insert(contents, rendered)
      else
        for _, v in pairs(rendered) do
          table.insert(contents, v)
        end
      end
    end
  else
    table.insert(contents, centerish_string(project_name))
    local processed = helpers.process_tasks(tree[project_name])
    for _, t in pairs(processed) do
      ui.current_state.lines[#contents] = t

      local rendered = render_task(t)
      if type(rendered) == 'string' then
        table.insert(contents, rendered)
      else
        for _, v in pairs(rendered) do
          table.insert(contents, v)
        end
      end
    end
  end
  ui.current_state.lines = helpers.flatten_with_children(ui.current_state.lines)

  return contents
end

local function create_task_win()
  local ret = win_float_helpers.centered({percentage = 0.8, winblend = 0})
  local bufnr = ret.buf
  local win_id = ret.win
  ui.current_state.win_id = win_id
  ui.current_state.bufnr = bufnr
  local contents = create_buffer_lines()
  api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
  api.nvim_win_set_cursor(win_id, {2, 1})
  api.nvim_buf_set_option(bufnr, 'modifiable', false)
  api.nvim_buf_set_option(bufnr, 'filetype', 'todoist')
  api.nvim_set_current_win(win_id)
end

function ui.move_cursor(up)
  assert_in_todoist()
  local win_id = ui.current_state.win_id
  local curr_pos = api.nvim_win_get_cursor(win_id)
  local next_row = up and curr_pos[1] - 1 or curr_pos[1] + 1
  local next_line = helpers.getline(ui.current_state.bufnr, next_row)
  if next_line then
    local start = string.find(next_line, ({vim.pesc(ui.current_state.task_start)})[1])
    start =
      start or string.find(next_line, ({vim.pesc(ui.current_state.checked_task_start)})[1])
    if start then
      api.nvim_win_set_cursor(win_id, {next_row, start})
    end
  end
end

function ui.update_buffer()
  local win_id = ui.current_state.win_id
  local bufnr = ui.current_state.bufnr
  local cursor_pos = api.nvim_win_get_cursor(win_id)
  local lines = create_buffer_lines()
  api.nvim_buf_set_option(bufnr, 'modifiable', true)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  api.nvim_buf_set_option(bufnr, 'modifiable', false)
  if cursor_pos[1] > #lines then
    api.nvim_win_set_cursor(win_id, {#lines, cursor_pos[2]})
  end
end

local function change_line_to(new_line)
  local bufnr = ui.current_state.bufnr
  local row = api.nvim_win_get_cursor(ui.current_state.win_id)[1]
  api.nvim_buf_set_option(bufnr, 'modifiable', true)
  api.nvim_buf_set_lines(bufnr, row - 1, row, false, {new_line})
  api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

local function uncheck_task(current_line)
  local state = ui.current_state
  local new_line, _ = current_line:gsub(state.checked_task_start_pat, state.task_start)
  change_line_to(new_line)

  local task = state.lines[api.nvim_win_get_cursor(state.win_id)[1] - 1]

  todoist_api.reopen_task(state.api_key, task.id)
  task.completed = false
  ui.current_state.completed_tasks =
    vim.tbl_filter(
      function(x)
        return x.id == task.id
      end,
      state.completed_tasks
    )
end

local function check_task(current_line)
  local state = ui.current_state
  local new_line, _ = current_line:gsub(state.task_start_pat, state.checked_task_start)
  change_line_to(new_line)
  local task = state.lines[api.nvim_win_get_cursor(state.win_id)[1] - 1]
  todoist_api.close_task(state.api_key, task.id)
  task.completed = true
  if ui.current_state.completed_tasks then
    table.insert(ui.current_state.completed_tasks, task)
  else
    ui.current_state.completed_tasks = {task}
  end
end

function ui.check_or_uncheck_task()
  assert_in_todoist()
  local state = ui.current_state
  local current_line = api.nvim_get_current_line()
  if current_line:find(state.checked_task_start_pat) then
    uncheck_task(current_line)
  else
    check_task(current_line)
  end
  ui.update_buffer()
end

function ui.delete_task()
  assert_in_todoist()
  local task = ui.current_state.lines[api.nvim_win_get_cursor(ui.current_state.wion_id)[1] - 1]
  todoist_api.delete_task(ui.current_state.api_key, task.id, function() ui.refresh() end)
end

function ui.refresh()
  assert_in_todoist()
  todoist_api.fetch_active_tasks(
    ui.current_state.api_key,
    function(tasks)
      todoist_api.fetch_projects(
        ui.current_state.api_key,
        function(projects)
          ui.current_state =
            vim.tbl_extend("force", ui.current_state, {tasks = tasks, projects = projects})
          ui.update_buffer()
        end
      )
    end
  )
end

function ui.init()
  todoist_api.fetch_active_tasks(
    ui.current_state.api_key,
    function(tasks)
      todoist_api.fetch_projects(
        ui.current_state.api_key,
        function(projects)
          ui.current_state =
            vim.tbl_extend("error", ui.current_state, {tasks = tasks, projects = projects})
          ui.current_state.initialized = true
        end
      )
    end
  )
end

function ui.render(daily_tasks_only, project_name)
  if ui.current_state.initialized then
    ui.current_state.daily_tasks_only = daily_tasks_only
    ui.current_state.project_name = project_name
    if helpers.is_current_win(ui.current_state.win_id) then
      ui.update_buffer()
    else
      create_task_win()
    end
  else
    -- TODO(smolck)
    error('UI hasn\'t been initialized. Call require\'nvim-todoist.ui\'.init()')
  end
end

return ui
