local plugin = require('neovim-plugin')(vim)
local ui = require('nvim-todoist.ui')
local helpers = require('nvim-todoist.helpers')
local todoist_api = require('nvim-todoist.api')
local nvim_todoist = {}
local state = {}
local initialized = false

local api_key = nvim_todoist.api_key or os.getenv('TODOIST_API_KEY')

nvim_todoist.neovim_stuff = plugin.export {
  mappings = {
    -- j = function()
    -- end;
  };

  commands = {
    Todoist = {
      function(project_name)
        assert(initialized,
          [[ You didn't initialize nvim-todoist.lua! Call require'nvim_todoist.lua'.neovim_stuff.use_defaults() ]])

        state.project_name = project_name ~= "" and project_name or 'Inbox'

        -- TODO(smolck): opts vs. state . . . ?
        state.checked_task_start = nvim_todoist.neovim_stuff.checked_task_start or '[x] ';
        state.task_start = nvim_todoist.neovim_stuff.task_start or '[ ] ';

        local opts = {
          -- TODO(smolck): Don't just do false, let user decide.
          daily_tasks_only = false;
          checked_task_start = nvim_todoist.neovim_stuff.checked_task_start or '[x] ';
          task_start = nvim_todoist.neovim_stuff.task_start or '[ ] ';
        }

        if state.win_id then
          if helpers.is_current_win(state.win_id) then
            ui.update_buffer(state, opts)
            return
          end
        end

        -- TODO(smolck): Fix this really messy code.
        state.opts = opts

        ui.create_task_win(state, opts)
      end;
      nargs = '?';
    };
    TodoistMoveCursorDown = function() ui.move_cursor(state, false) end;
    TodoistMoveCursorUp = function() ui.move_cursor(state, true) end;
    TodoistCreateTask = function() ui.create_task(state, api_key) end;
    TodoistDeleteTask = function() ui.delete_task(state, api_key) end;
    TodoistToggleTask = function() ui.check_or_uncheck_task(state, api_key) end;
    TodoistRefresh = function() ui.refresh(state, api_key) end;
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
