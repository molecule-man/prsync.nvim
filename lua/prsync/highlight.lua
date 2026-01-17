-- Highlight user-added PR comments in prsync worktrees.

local M = {}

M.ns = vim.api.nvim_create_namespace("prsync_comments")

local cached_is_worktree = nil
local offline_review_enabled = false
local offline_review_commit = nil

---Check if current directory is a prsync worktree
---@return boolean
function M.is_prsync_worktree()
  if cached_is_worktree ~= nil then
    return cached_is_worktree
  end
  local branch = vim.fn.system("git rev-parse --abbrev-ref HEAD 2>/dev/null")
  branch = vim.trim(branch)
  cached_is_worktree = branch:match("^prsync/review%-pr%-(%d+)$") ~= nil
  return cached_is_worktree
end

local function get_draft_async(callback, is_offline, commit)
  local cli = require("prsync.cli")
  local global_args = { "-q" }
  local cmd_args = { "-dry-run", "-format", "json" }
  if is_offline then
    table.insert(cmd_args, "-offline")
    if commit then
      table.insert(cmd_args, "-commit")
      table.insert(cmd_args, commit)
    end
  end
  cli.run_async("comment", cmd_args, global_args, function(result, err)
    if err then
      callback(nil)
      return
    end
    callback(result)
  end)
end

local function clear_highlights(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
end

local function apply_highlights(bufnr)
  clear_highlights(bufnr)

  local is_offline = offline_review_enabled
  if not is_offline and not M.is_prsync_worktree() then
    return
  end

  get_draft_async(function(draft)
    -- Buffer may have been closed while waiting for async response
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    if not draft or type(draft.files) ~= "table" then
      return
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local cwd = vim.fn.getcwd()
    local rel_path = bufname:sub(#cwd + 2) -- strip cwd/ prefix

    for _, file in ipairs(draft.files) do
      if file.path == rel_path then
        for _, comment in ipairs(file.comments or {}) do
          -- Skip suggestions (only highlight pure comments)
          if comment.suggestion and comment.suggestion ~= "" then
            goto continue
          end

          -- Highlight anchor lines (yellowish)
          if comment.anchor_start and comment.anchor_end then
            for line = comment.anchor_start, comment.anchor_end do
              pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns, line - 1, 0, {
                line_hl_group = "PrsyncAnchor",
                hl_eol = true,
              })
            end
          end

          -- Highlight comment lines (greenish)
          if comment.content_start and comment.content_end then
            for line = comment.content_start, comment.content_end do
              pcall(vim.api.nvim_buf_set_extmark, bufnr, M.ns, line - 1, 0, {
                line_hl_group = "PrsyncComment",
                hl_eol = true,
              })
            end
          end

          ::continue::
        end
        break
      end
    end
  end, is_offline, offline_review_commit)
end

function M.setup_autocmds()
  vim.api.nvim_set_hl(0, "PrsyncAnchor", { bg = "#3d3810", default = true })
  vim.api.nvim_set_hl(0, "PrsyncComment", { bg = "#1a3d10", default = true })

  local augroup = vim.api.nvim_create_augroup("PrsyncHighlight", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = augroup,
    callback = function(ev)
      apply_highlights(ev.buf)
    end,
  })

  -- Invalidate cache on directory change
  vim.api.nvim_create_autocmd("DirChanged", {
    group = augroup,
    callback = function()
      cached_is_worktree = nil
    end,
  })
end

---Enable offline review mode
---@param commit string|nil Optional commit to diff against (defaults to HEAD)
function M.set_offline_review(commit)
  offline_review_enabled = true
  offline_review_commit = commit
  local bufnr = vim.api.nvim_get_current_buf()
  apply_highlights(bufnr)
end

---Disable offline review mode and clear all highlights
function M.clear_offline_review()
  offline_review_enabled = false
  offline_review_commit = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
    end
  end
end

---Check if offline review mode is enabled
---@return boolean
function M.is_offline_review()
  return offline_review_enabled
end

---Get the commit to diff against in offline review mode
---@return string|nil
function M.get_offline_review_commit()
  return offline_review_commit
end

return M
