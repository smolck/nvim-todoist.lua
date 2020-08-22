package.loaded['nvim-todoist.ui'] = nil
local vim = vim
local api = vim.api
local todoist_api = require('nvim-todoist.api')
local win_float_helpers = require('plenary.window.float')
local helpers = require('nvim-todoist.helpers')
local first = helpers.first
local ui = {}

local function assert_in_todoist()
  assert(api.nvim_buf_get_option(0, 'filetype') == 'todoist', 'Not in Todoist buffer')
end

local function render_task(task, checked_task_start, task_start, padding)
  local padding = padding or ''
  local task_ending = ''
  if task.due and task.due.date then
    task_ending = ' (' .. task.due.date .. ')'
  end
  local rendered
  if task.completed then
    rendered = padding .. checked_task_start .. task.content .. task_ending
  else
    rendered = padding .. task_start .. task.content .. task_ending
  end
  if task.children then
    local lines = {}
    table.insert(lines, rendered)
    for _, t in pairs(task.children) do
      table.insert(lines, render_task(t, checked_task_start, task_start, padding .. '    '))
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

local function centerish_string(win_id, str)
  local w = api.nvim_win_get_width(win_id)
  return string.rep(' ', w / 2 - 10) .. str
end

local function create_buffer_lines(state, opts)
  state.tasks_index = {}
  local daily_tasks_only = opts.daily_tasks_only or false
  local project_name = state.project_name
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
    table.insert(contents, centerish_string(state.win_id, 'Daily'))
    local processed = helpers.process_tasks(vim.tbl_filter(is_recurring_task, tasks))
    for _, t in pairs(processed) do
      state.tasks_index[#contents] = t

      local rendered = render_task(t, opts.checked_task_start, opts.task_start)
      if type(rendered) == 'string' then
        table.insert(contents, rendered)
      else
        for _, v in pairs(rendered) do
          table.insert(contents, v)
        end
      end
    end
  else
    table.insert(contents, centerish_string(state.win_id, project_name))
    local processed = helpers.process_tasks(tree[project_name])
    for _, t in pairs(processed) do
      state.tasks_index[#contents] = t

      local rendered = render_task(t, opts.checked_task_start, opts.task_start)
      if type(rendered) == 'string' then
        table.insert(contents, rendered)
      else
        for _, v in pairs(rendered) do
          table.insert(contents, v)
        end
      end
    end
  end
  state.tasks_index = helpers.flatten_with_children(state.tasks_index)

  return contents
end

function ui.create_task_win(state, opts)
  local ret = win_float_helpers.centered({percentage = 0.8, winblend = 0})
  local bufnr, win_id = ret.bufnr, ret.win_id
  state.win_id = win_id
  state.bufnr = bufnr

  local contents = create_buffer_lines(state, opts)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, contents)
  api.nvim_win_set_cursor(win_id, {2, 1})
  api.nvim_buf_set_option(bufnr, 'modifiable', false)
  api.nvim_buf_set_option(bufnr, 'filetype', 'todoist')
  api.nvim_set_current_win(win_id)
end

function ui.move_cursor(state, up)
  assert_in_todoist()
  local win_id = state.win_id
  local curr_pos = api.nvim_win_get_cursor(win_id)
  local next_row = up and curr_pos[1] - 1 or curr_pos[1] + 1
  local next_line = helpers.getline(state.bufnr, next_row)
  if next_line then
    local start = string.find(next_line, first(vim.pesc(state.task_start)))
    start =
      start or string.find(next_line, first(vim.pesc(state.checked_task_start)))
    if start then
      api.nvim_win_set_cursor(win_id, {next_row, start})
    end
  end
end

function ui.update_buffer(state, opts)
  local win_id = state.win_id
  local bufnr = state.bufnr
  local cursor_pos = api.nvim_win_get_cursor(win_id)
  local lines = create_buffer_lines(state, opts)
  api.nvim_buf_set_option(bufnr, 'modifiable', true)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  api.nvim_buf_set_option(bufnr, 'modifiable', false)
  if cursor_pos[1] > #lines then
    api.nvim_win_set_cursor(win_id, {#lines, cursor_pos[2]})
  end
end

local function change_line_to(win_id, bufnr, new_line)
  local row = api.nvim_win_get_cursor(win_id)[1]
  api.nvim_buf_set_option(bufnr, 'modifiable', true)
  api.nvim_buf_set_lines(bufnr, row - 1, row, false, {new_line})
  api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

local function uncheck_task(state, api_key, current_line)
  local new_line, _ = current_line:gsub(
    -- TODO(smolck): Verify this is correct, was: state.checked_task_start_pat
    first(vim.pesc(state.checked_task_start)),
    state.task_start
  )
  change_line_to(state.win_id, state.bufnr, new_line)
  local task = state.tasks_index[api.nvim_win_get_cursor(state.win_id)[1] - 1]

  todoist_api.reopen_task(api_key, task.id)
  task.completed = false
  state.completed_tasks =
    vim.tbl_filter(
      function(x)
        return x.id == task.id
      end,
      state.completed_tasks
    )
end

local function check_task(state, api_key, current_line)
  -- TODO(smolck): local new_line, _ = current_line:gsub(ui.state.task_start_pat, ui.state.checked_task_start)
  local new_line, _ = current_line:gsub(
    first(vim.pesc(state.task_start)),
    state.checked_task_start
  )
  change_line_to(state.win_id, state.bufnr, new_line)
  local task = state.tasks_index[api.nvim_win_get_cursor(state.win_id)[1] - 1]

  todoist_api.close_task(api_key, task.id)
  task.completed = true
  if state.completed_tasks then
    table.insert(state.completed_tasks, task)
  else
    state.completed_tasks = {task}
  end
end

function ui.check_or_uncheck_task(state, api_key)
  assert_in_todoist()
  local current_line = api.nvim_get_current_line()
  -- TODO(smolck): if current_line:find(ui.state.checked_task_start_pat) then
  if current_line:find(first(vim.pesc(state.checked_task_start))) then
    uncheck_task(state, api_key, current_line)
  else
    check_task(state, api_key, current_line)
  end
  ui.update_buffer(state, state.opts)
end

function ui.create_task(state, api_key)
  assert_in_todoist()
  local content = vim.fn.input('Content: ')
  assert(content ~= '', 'Content field required')

  local due = vim.fn.input('Due: ')

  todoist_api.create_task(api_key, {
    content = content,
    due_string = due ~= "" and due or nil,
    project_id = vim.tbl_filter(
      function(x) return x.name == state.project_name end,
      state.projects
    )[1].id
  }, function() ui.refresh(state, api_key) end)
end

function ui.delete_task(state, api_key)
  assert_in_todoist()
  local task = state.tasks_index[api.nvim_win_get_cursor(state.win_id)[1] - 1]
  todoist_api.delete_task(api_key, task.id, function() ui.refresh(state, api_key) end)
end

function ui.refresh(state, api_key)
  assert_in_todoist()
  todoist_api.fetch_active_tasks(
    api_key,
    function(tasks)
      todoist_api.fetch_projects(
        api_key,
        function(projects)
          state =
            vim.tbl_extend("force", state, {tasks = tasks, projects = projects})

          ui.update_buffer(state, state.opts)
        end
      )
    end
  )
end

return ui
