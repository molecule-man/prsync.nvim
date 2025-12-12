-- UI components for prsync.nvim

local M = {}

local function build_info_lines(pr, start_result)
  return {
    string.format("PR #%d: %s", pr.number, pr.title),
    string.format("Author: %s", pr.author),
    string.format("Base: %s → Head: %s", pr.base, pr.head),
    "",
    "═══════════════════════════════════════════════════════",
    "",
    "Review Workflow:",
    "  1. Browse files and inspect changes",
    "  2. Edit code to add comments (prefix with // or #)",
    "  3. Make code suggestions by modifying lines directly",
    "  4. Run :PrsyncApprove, :PrsyncReject, or :PrsyncComment",
    "",
    "Commands:",
    "  :PrsyncApprove   - Submit review with APPROVE",
    "  :PrsyncReject    - Submit review with REQUEST_CHANGES",
    "  :PrsyncComment   - Submit review as COMMENT only",
    "",
    "═══════════════════════════════════════════════════════",
    "",
    string.format("Worktree: %s", start_result.path),
  }
end

---Show info buffer for a review session
---@param pr table PR object from prs command
---@param start_result table Result from start command
function M.show_info(pr, start_result)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = build_info_lines(pr, start_result)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_buf_set_name(buf, string.format("prsync://pr/%d", pr.number))

  vim.api.nvim_set_current_buf(buf)
end

return M
