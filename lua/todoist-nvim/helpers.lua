package.loaded['todoist-nvim.helpers'] = nil
local vim = vim
local helpers = {}

function helpers.process_tasks(tasks)
  local tasks_by_id = {}
  for _, t in ipairs(tasks) do
    tasks_by_id[t.id] = t
  end

  local processed = tasks_by_id
  local ids = {}
  for id, t in pairs(tasks_by_id) do
    if t.parent_id then
      if processed[t.parent_id].children then
        processed[t.parent_id].children[id] = t
      else
        processed[t.parent_id].children = { [id] = t }
      end

      table.insert(ids, id)
    end
  end

  for _, id in pairs(ids) do
    processed[id] = nil
  end

  return processed
end

return helpers
