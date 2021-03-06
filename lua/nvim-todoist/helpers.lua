package.loaded['nvim-todoist.helpers'] = nil
local vim = vim
local api = vim.api
local helpers = {}

function helpers.assert_in_todoist()
  assert(api.nvim_buf_get_option(0, 'filetype') == 'todoist', 'Not in Todoist buffer')
end

function helpers.first(...)
  local x = select(1, ...)
  return x
end

function helpers.is_current_win(win_id)
  return vim.api.nvim_get_current_win() == win_id
end

function helpers.getline(bufnr, lnum, strict_indexing)
  local strict_indexing = strict_indexing or true
  local worked, res = pcall(vim.api.nvim_buf_get_lines, bufnr, lnum - 1, lnum, strict_indexing)
  if worked then
    return res[1]
  else
    return nil
  end
end

function helpers.flatten_with_children(tbl)
  local ret = {}

  for _, v in pairs(tbl) do
    table.insert(ret, v)
    if v.children then
      for _, v2 in pairs(helpers.flatten_with_children(v.children)) do
        table.insert(ret, v2)
      end
    end
  end

  return ret
end

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
        processed[t.parent_id].children = {[id] = t}
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
