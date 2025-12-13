-- PR picker with Telescope support and vim.ui.select fallback

local M = {}

local function has_telescope()
  return pcall(require, "telescope")
end

local function telescope_pick(prs, callback)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = "Select PR to Review",
      finder = finders.new_table({
        results = prs,
        entry_maker = function(pr)
          return {
            value = pr,
            display = string.format("#%d %s (%s)", pr.number, pr.title, pr.author),
            ordinal = string.format("%d %s %s", pr.number, pr.title, pr.author),
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            callback(selection.value)
          else
            callback(nil)
          end
        end)
        return true
      end,
    })
    :find()
end

local function fallback_pick(prs, callback)
  local items = {}
  for _, pr in ipairs(prs) do
    table.insert(items, string.format("#%d %s (%s)", pr.number, pr.title, pr.author))
  end

  vim.ui.select(items, { prompt = "Select PR to review:" }, function(_, idx)
    if idx then
      callback(prs[idx])
    else
      callback(nil)
    end
  end)
end

---Pick a PR from the list
---@param prs table[] List of PR objects
---@param callback fun(pr: table|nil) Called with selected PR or nil if cancelled
function M.pick_pr(prs, callback)
  if has_telescope() then
    telescope_pick(prs, callback)
  else
    fallback_pick(prs, callback)
  end
end

return M
