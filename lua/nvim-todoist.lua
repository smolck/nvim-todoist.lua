local plugin = require('nvim-todoist.neovim-plugin.lua.neovim-plugin')(vim)
local ui = require('nvim-todoist.ui')
local helpers = require('nvim-todoist.helpers')
local todoist_api = require('nvim-todoist.api')
local functional = require('plenary.functional')
local api = vim.api
local nvim_todoist = {}
local state = {}
local initialized = false

local api_key = nvim_todoist.api_key or os.getenv('TODOIST_API_KEY')

local function update_tasks_and_projects(cb)
  todoist_api.fetch_active_tasks(api_key,
    function(tasks)
      todoist_api.fetch_projects(
        api_key,
        function(projects)
          state = vim.tbl_extend('force', state, {tasks = tasks, projects = projects})

          cb()
        end
      )
    end
  )
end

local function fetch_and_refresh()
  helpers.assert_in_todoist()

  update_tasks_and_projects(function()
    state.tasks_index =
      ui.refresh(
        state.win_id,
        state.bufnr,
        state.tasks,
        state.projects,
        state.project_name,
        nvim_todoist.user_opts)
  end)
end


nvim_todoist.user_opts = {
  -- TODO(smolck): Don't just do false, let user decide.
  daily_tasks_only = false;
  checked_task_start = '[x] ';
  task_start = '[ ] ';
}

nvim_todoist.neovim_stuff = plugin.export {
  functions = {
    fetch_and_refresh = fetch_and_refresh;
    todoist = function(project_name)
      assert(initialized,
        [[ You didn't initialize nvim-todoist.lua! Call require'nvim_todoist.lua'.neovim_stuff.use_defaults() ]])

      project_name = project_name ~= "" and project_name or 'Inbox'
      if state.win_id and helpers.is_current_win(state.win_id) then
        if state.project_name == project_name then
          print(
            'Todoist window is already open! Did you mean `:TodoistRefresh`?'
          )
          return
        else
          api.nvim_win_close(state.win_id, true)
        end
      end

      state.project_name = project_name

      local res = ui.create_task_win(state.projects, state.tasks, state.project_name, nvim_todoist.user_opts)
      state.tasks_index = res.tasks_index
      state.win_id = res.win_id
      state.bufnr = res.bufnr
    end;

    todoist_move_cursor_up = function()
      ui.move_cursor(
        state.win_id,
        state.bufnr,
        nvim_todoist.user_opts,
        true)
    end;

    todoist_move_cursor_down = function()
      ui.move_cursor(
        state.win_id,
        state.bufnr,
        nvim_todoist.user_opts,
        false)
    end;

    todoist_toggle_task = function()
      helpers.assert_in_todoist()
      local current_line = api.nvim_get_current_line()
      local task = state.tasks_index[api.nvim_win_get_cursor(state.win_id)[1] - 1]

      if current_line:find(functional.first(vim.pesc(nvim_todoist.user_opts.checked_task_start))) then
        ui.uncheck_task(
          state.win_id,
          state.bufnr,
          nvim_todoist.user_opts.checked_task_start,
          nvim_todoist.user_opts.task_start)

        todoist_api.reopen_task(api_key, task.id)
        task.completed = false
        state.completed_tasks =
          vim.tbl_filter(
            function(x)
              return x.id == task.id
            end,
          state.completed_tasks
        )
      else
        ui.check_task(
          state.win_id,
          state.bufnr,
          nvim_todoist.user_opts.checked_task_start,
          nvim_todoist.user_opts.task_start)

        todoist_api.close_task(api_key, task.id)
        task.completed = true
        if state.completed_tasks then
          table.insert(state.completed_tasks, task)
        else
          state.completed_tasks = {task}
        end
      end
    end;

    todoist_delete_task = function()
      helpers.assert_in_todoist()

      local task = state.tasks_index[api.nvim_win_get_cursor(state.win_id)[1] - 1]
      todoist_api.delete_task(
        api_key,
        task.id,
        fetch_and_refresh
      )
    end;

    todoist_create_task = function()
      helpers.assert_in_todoist()

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
      }, fetch_and_refresh)
    end;
  };

  commands = {
    TodoistRefresh = 'fetch_and_refresh';
    Todoist = { 'todoist'; nargs = '?'; };
    TodoistMoveCursorDown = 'todoist_move_cursor_down';
    TodoistMoveCursorUp = 'todoist_move_cursor_up';
    TodoistCreateTask = 'todoist_create_task';
    TodoistDeleteTask = 'todoist_delete_task';
    TodoistToggleTask = 'todoist_toggle_task';
    -- TodoistRefresh = function() ui.refresh(state, api_key) end;
  };

  setup = function()
    todoist_api.fetch_active_tasks(api_key,
      function(tasks)
        todoist_api.fetch_projects(
          api_key,
          function(projects)
            state = vim.tbl_extend('error', state, {tasks = tasks, projects = projects})

            initialized = true
          end
        )
      end
    )
  end;
}

return nvim_todoist
