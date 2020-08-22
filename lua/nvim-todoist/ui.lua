package.loaded['nvim-todoist.ui'] = nil
local vim = vim
local api = vim.api
local todoist_api = require('nvim-todoist.api')
local win_float_helpers = require('plenary.window.float')
local helpers = require('nvim-todoist.helpers')
local first = helpers.first
local assert_in_todoist = helpers.assert_in_todoist
local ui = {}

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

local function create_buffer_lines(win_id, tasks, project_name, checked_task_start, task_start)
  local tasks_index = {}
  local contents = {}

  table.insert(contents, centerish_string(win_id, project_name))
  local processed = helpers.process_tasks(tasks)
  for _, t in pairs(processed) do
    tasks_index[#contents] = t
    local rendered = render_task(t, checked_task_start, task_start)

    if type(rendered) == 'string' then
      table.insert(contents, rendered)
    else
      for _, v in pairs(rendered) do
        table.insert(contents, v)
      end
    end
  end
  tasks_index = helpers.flatten_with_children(tasks_index)

  return {
    contents = contents;
    tasks_index = tasks_index;
  }
end

function ui.create_task_win(projects, tasks, project_name, opts)
  local ret = win_float_helpers.centered({percentage = 0.8, winblend = 0})
  local bufnr, win_id = ret.bufnr, ret.win_id

  local project_id =
    vim.tbl_filter(function(proj) return proj.name == project_name end, projects)[1].id
  local filtered_tasks =
    vim.tbl_filter(function(task) return task.project_id == project_id end, tasks)

  local res = create_buffer_lines(
    win_id,
    filtered_tasks,
    project_name,
    opts.checked_task_start,
    opts.task_start
  )
  api.nvim_buf_set_lines(bufnr, 0, -1, false, res.contents)
  api.nvim_win_set_cursor(win_id, {2, 1})
  api.nvim_buf_set_option(bufnr, 'modifiable', false)
  api.nvim_buf_set_option(bufnr, 'filetype', 'todoist')
  api.nvim_set_current_win(win_id)

  return {
    tasks_index = res.tasks_index;
    win_id = win_id;
    bufnr = bufnr;
  }
end

function ui.move_cursor(win_id, bufnr, opts, up)
  assert_in_todoist()
  local curr_pos = api.nvim_win_get_cursor(win_id)
  local next_row = up and curr_pos[1] - 1 or curr_pos[1] + 1
  local next_line = helpers.getline(bufnr, next_row)
  if next_line then
    local start = string.find(next_line, first(vim.pesc(opts.task_start)))
    start =
      start or string.find(next_line, first(vim.pesc(opts.checked_task_start)))
    if start then
      api.nvim_win_set_cursor(win_id, {next_row, start})
    end
  end
end

local function change_line_to(win_id, bufnr, new_line)
  local row = api.nvim_win_get_cursor(win_id)[1]
  api.nvim_buf_set_option(bufnr, 'modifiable', true)
  api.nvim_buf_set_lines(bufnr, row - 1, row, false, {new_line})
  api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

function ui.uncheck_task(win_id, bufnr, checked_task_start, task_start)
  local current_line = api.nvim_get_current_line()
  local new_line, _ = current_line:gsub(
    first(vim.pesc(checked_task_start)),
    task_start
  )
  change_line_to(win_id, bufnr, new_line)
end

function ui.check_task(win_id, bufnr, checked_task_start, task_start)
  local current_line = api.nvim_get_current_line()
  local new_line, _ = current_line:gsub(
    first(vim.pesc(task_start)),
    checked_task_start
  )
  change_line_to(win_id, bufnr, new_line)
end

function ui.refresh(win_id, bufnr, tasks, projects, project_name, opts)
  local project_id =
    vim.tbl_filter(function(proj) return proj.name == project_name end, projects)[1].id
  local filtered_tasks =
    vim.tbl_filter(function(task) return task.project_id == project_id end, tasks)

  local cursor_pos = api.nvim_win_get_cursor(win_id)

  local res = create_buffer_lines(
    win_id,
    filtered_tasks,
    project_name,
    opts.checked_task_start,
    opts.task_start
  )
  api.nvim_buf_set_option(bufnr, 'modifiable', true)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, res.contents)
  api.nvim_buf_set_option(bufnr, 'modifiable', false)
  if cursor_pos[1] > #res.contents then
    api.nvim_win_set_cursor(win_id, {#res.contents, cursor_pos[2]})
  end

  return res.tasks_index
end

return ui
