-- User command implementations for prsync.nvim

local cli = require("prsync.cli")
local picker = require("prsync.picker")
local ui = require("prsync.ui")
local highlight = require("prsync.highlight")

local M = {}

-- Track draft buffer state to avoid double-submit on BufUnload
local draft_submitted = {}

---Start a PR review session
---Pick PR, create/attach worktree, open review tab
function M.start()
  local prs, err = cli.run("prs", { "-format", "json" }, { "-q" })
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

    local result, start_err = cli.run("start", { "-format", "json" }, { "-q", "-pr", pr.number })
    if start_err then
      vim.notify("prsync: " .. start_err, vim.log.levels.ERROR)
      return
    end

    vim.cmd("tabnew")
    vim.cmd("tcd " .. vim.fn.fnameescape(result.path))
    ui.show_info(pr, result)
  end)
end

local function prompt_cleanup()
  vim.ui.input({ prompt = "Cleanup worktree? [y/N]: " }, function(input)
    if input and input:lower() == "y" then
      local _, err = cli.run("cleanup", {}, { "-q" })
      if err then
        vim.notify("prsync: " .. err, vim.log.levels.ERROR)
      else
        vim.notify("Worktree cleaned up", vim.log.levels.INFO)
      end
    end
  end)
end

local function submit_draft(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  local _, err = cli.run_with_stdin("submit", content, {}, { "-q" })
  if err then
    vim.notify("prsync: " .. err, vim.log.levels.ERROR)
    return false
  end

  vim.notify("Review submitted", vim.log.levels.INFO)
  return true
end

local function submit_and_close(buf)
  if submit_draft(buf) then
    draft_submitted[buf] = true
    vim.api.nvim_buf_delete(buf, { force = true })
    prompt_cleanup()
  end
end

local function open_draft_buffer(content)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "xml", { buf = buf })
  vim.api.nvim_buf_set_name(buf, "prsync://draft")

  -- Buffer-local submit command
  vim.api.nvim_buf_create_user_command(buf, "PrsyncSubmit", function()
    submit_and_close(buf)
  end, {})

  -- Prompt on close
  vim.api.nvim_create_autocmd("BufUnload", {
    buffer = buf,
    once = true,
    callback = function()
      if draft_submitted[buf] then
        draft_submitted[buf] = nil
        return
      end

      -- Capture content before buffer is gone
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local draft_content = table.concat(lines, "\n")

      -- Schedule prompt to avoid issues during BufUnload
      vim.schedule(function()
        vim.ui.input({ prompt = "Submit review? [Y/n]: " }, function(input)
          if input == nil then
            -- User cancelled (Esc)
            return
          end
          if input == "" or input:lower() == "y" then
            local _, err = cli.run_with_stdin("submit", draft_content, {}, { "-q" })
            if err then
              vim.notify("prsync: " .. err, vim.log.levels.ERROR)
            else
              vim.notify("Review submitted", vim.log.levels.INFO)
              prompt_cleanup()
            end
          end
        end)
      end)
    end,
  })

  vim.api.nvim_set_current_buf(buf)
end

local function review_action(action)
  if not highlight.is_prsync_worktree() then
    vim.notify("prsync: not in a prsync worktree", vim.log.levels.WARN)
    return
  end

  local draft, err = cli.run(action, { "-dry-run" }, { "-q" })
  if err then
    vim.notify("prsync: " .. err, vim.log.levels.ERROR)
    return
  end

  open_draft_buffer(draft)
end

---Submit review with APPROVE
function M.approve()
  review_action("approve")
end

---Submit review with COMMENT
function M.comment()
  review_action("comment")
end

---Submit review with REQUEST_CHANGES
function M.reject()
  review_action("reject")
end

return M
