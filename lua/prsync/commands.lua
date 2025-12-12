-- User command implementations for prsync.nvim

local cli = require("prsync.cli")
local picker = require("prsync.picker")
local ui = require("prsync.ui")

local M = {}

---Start a PR review session
---Pick PR, create/attach worktree, open review tab
function M.start()
  local prs, err = cli.run("prs", { "-format", "json", "-q" })
  if err then
    vim.notify("prsync: " .. err, vim.log.levels.ERROR)
    return
  end

  if not prs or #prs == 0 then
    vim.notify("prsync: no open PRs found", vim.log.levels.WARN)
    return
  end

  picker.pick_pr(prs, function(pr)
    if not pr then
      return
    end

    local result, start_err = cli.run("start", { "-pr", pr.number, "-format", "json", "-q" })
    if start_err then
      vim.notify("prsync: " .. start_err, vim.log.levels.ERROR)
      return
    end

    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(result.path))
    ui.show_info(pr, result)
  end)
end

---Submit review with APPROVE
function M.approve()
  -- TODO: implement
  vim.notify("PrsyncApprove: not implemented", vim.log.levels.WARN)
end

return M
