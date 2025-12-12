-- User command implementations for prsync.nvim

local M = {}

---Start a PR review session
---Pick PR, create/attach worktree, open review tab
function M.start()
  -- TODO: implement
  vim.notify("PrsyncStart: not implemented", vim.log.levels.WARN)
end

---Submit review with APPROVE
function M.approve()
  -- TODO: implement
  vim.notify("PrsyncApprove: not implemented", vim.log.levels.WARN)
end

return M
