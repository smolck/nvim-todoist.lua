package.loaded['todoist-nvim.api'] = nil

local vim = vim
local rapidjson = require('rapidjson')

local base_uri = 'https://api.todoist.com/rest/v1'

local api = {}

local function auth_str(api_key)
  return '"Authorization: Bearer ' .. api_key .. '"'
end

local function wrap_quotes(x)
  return '"' .. x .. '"'
end

function api.fetch_active_tasks(api_key, cb)
  vim.fn.jobstart(
    'curl -X GET "' .. base_uri .. '/tasks' .. '" -H "Authorization: Bearer ' .. api_key .. '"',
    {
      stdout_buffered = true,
      on_stdout =
        function(_, d, _)
          local json = rapidjson.decode(table.concat(d))
          cb(json)
        end,
    }
  )
end

function api.fetch_active_task(api_key, id, cb)
  local uri = wrap_quotes(base_uri .. '/tasks/' .. tostring(id))
  vim.fn.jobstart(
    'curl -X GET ' .. uri .. '-H ' .. auth_str(api_key),
    {
      stdout_bufferd = true,
      on_stdout =
        function(_, d, _)
          local json = rapidjson.decode(table.concat(d))
          cb(json)
        end,
    }
  )
end

-- TODO(smolck): Maybe verify req_body_tbl?

-- local function create_task(api_key, req_body_tbl)
--   local req = authenticated_req(api_key, base_uri .. '/tasks')
--   req.headers:upsert(':method', 'POST')
--   req.headers:upsert('content-type', 'application/json')
--   req:set_body(rapidjson.encode(req_body_tbl))
--   local headers, stream = assert(req:go())
--   local body = assert(stream:get_body_as_string())
--   if headers:get(":status") ~= "200" then
--     error(body)
--   end
--   return rapidjson.decode(body)
-- end

function api.fetch_projects(api_key, cb)
  local uri = wrap_quotes(base_uri .. '/projects')
  vim.fn.jobstart(
    'curl -X GET ' .. uri .. ' -H ' .. auth_str(api_key),
    {
      stdout_buffered = true,
      on_stdout =
        function(_, d, _)
          local json = rapidjson.decode(table.concat(d))
          cb(json)
        end,
    }
  )
end

function api.update_task(api_key, task_id, data)
  local uri = wrap_quotes(base_uri .. '/tasks/' .. tostring(task_id))
  vim.fn.jobstart(
    'curl -X POST ' .. uri .. ' -H ' .. auth_str(api_key) .. ' --data \'' .. rapidjson.encode(data) .. '\'',
    {}
  )
end

function api.close_task(api_key, task_id)
  local uri = wrap_quotes(base_uri .. '/tasks/' .. tostring(task_id) .. '/close')
  vim.fn.jobstart('curl -X POST ' .. uri .. ' -H ' .. auth_str(api_key))
end

function api.reopen_task(api_key, task_id)
  local uri = wrap_quotes(base_uri .. '/tasks/' .. tostring(task_id) .. '/reopen')
  vim.fn.jobstart('curl -X POST ' .. uri .. ' -H ' .. auth_str(api_key))
end

return api
