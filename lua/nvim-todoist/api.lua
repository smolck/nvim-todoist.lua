local vim = vim
local json = require('nvim-todoist.lib.json')
local base_uri = 'https://api.todoist.com/rest/v1'
local api = {}

local function auth_str(api_key)
  return '"Authorization: Bearer ' .. api_key .. '"'
end

function api.fetch_active_tasks(api_key, cb)
  vim.fn.jobstart(
    string.format('curl -X GET "%s" -H %s', base_uri .. '/tasks', auth_str(api_key)),
    {
      stdout_buffered = true,
      on_stdout =
        function(_, d, _)
          local json = json.decode(table.concat(d))
          cb(json)
        end,
    }
  )
end

function api.fetch_projects(api_key, cb)
  vim.fn.jobstart(
    string.format('curl -X GET "%s" -H %s', base_uri .. '/projects', auth_str(api_key)),
    {
      stdout_buffered = true,
      on_stdout =
        function(_, d, _)
          cb(json.decode(table.concat(d)))
        end,
    }
  )
end

function api.update_task(api_key, task_id, data)
  vim.fn.jobstart(
    string.format(
      'curl -X POST "%s" -H %s --data \'%s\'',
      base_uri .. '/tasks/' .. tostring(task_id),
      auth_str(api_key),
      json.encode(data)
    )
  )
end

function api.close_task(api_key, task_id)
  vim.fn.jobstart(
    string.format(
      'curl -X POST "%s" -H %s',
      base_uri .. '/tasks/' .. tostring(task_id) .. '/close',
      auth_str(api_key)
    )
  )
end

function api.reopen_task(api_key, task_id)
  vim.fn.jobstart(
    string.format(
      'curl -X POST "%s" -H %s',
      base_uri .. '/tasks/' .. tostring(task_id) .. '/reopen',
      auth_str(api_key)
    )
  )
end

function api.create_task(api_key, data, cb)
  vim.fn.jobstart(
    string.format(
      'curl -X POST "%s" --data \'%s\' -H %s -H "Content-Type: application/json"',
      base_uri .. '/tasks',
      json.encode(data),
      auth_str(api_key)
    ),
    cb and
    {
      stdout_buffered = true,
      on_stdout =
        function(_, d, _)
          cb(json.decode(table.concat(d)))
        end,
    } or
    nil
  )
end

function api.delete_task(api_key, task_id, cb)
  vim.fn.jobstart(
    string.format(
      'curl -X DELETE "%s" -H %s',
      base_uri .. '/tasks/' .. tostring(task_id),
      auth_str(api_key)
    ),
    cb and
    {
      stdout_buffered = true,
      on_stdout = function(_, d, _)
        cb(json.decode(table.concat(d)))
      end,
    } or
    nil
  )
end

return api
