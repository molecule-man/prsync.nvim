-- Visual mode wrapper for [PR]/[/PR] comment blocks.

local M = {}

local ns = vim.api.nvim_create_namespace("prsync_block")

---Extract comment prefix from buffer's commentstring option.
---@return string prefix The comment prefix (e.g., "// " or "# ")
function M.get_comment_prefix()
  local cs = vim.bo.commentstring
  if not cs or cs == "" then
    return "// "
  end
  -- commentstring format: "prefix%ssuffix" - extract prefix before %s
  local prefix = cs:match("^(.-)%%s")
  if not prefix or prefix == "" then
    return "// "
  end
  -- Ensure prefix ends with a space
  if not prefix:match("%s$") then
    prefix = prefix .. " "
  end
  return prefix
end

---Apply highlights to marker and content lines.
---@param bufnr number Buffer number
---@param marker_start number Line number of opening [PR] marker (1-indexed)
---@param marker_end number Line number of closing [/PR] marker (1-indexed)
---@param comment_line number Line number of comment line (1-indexed)
---@param anchor_start number First line of anchored content (1-indexed)
---@param anchor_end number Last line of anchored content (1-indexed)
function M.apply_block_highlights(bufnr, marker_start, marker_end, comment_line, anchor_start, anchor_end)
  -- Marker lines (dimmed)
  pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, marker_start - 1, 0, {
    line_hl_group = "PrsyncMarker",
    hl_eol = true,
  })
  pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, marker_end - 1, 0, {
    line_hl_group = "PrsyncMarker",
    hl_eol = true,
  })

  -- Anchor lines (yellowish)
  for line = anchor_start, anchor_end do
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, line - 1, 0, {
      line_hl_group = "PrsyncAnchor",
      hl_eol = true,
    })
  end

  -- Comment line (greenish)
  pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, comment_line - 1, 0, {
    line_hl_group = "PrsyncComment",
    hl_eol = true,
  })
end

---Add virtual text hint showing which lines are being commented.
---@param bufnr number Buffer number
---@param comment_line number Line number for the hint (1-indexed)
---@param orig_start number Original selection start line (1-indexed)
---@param orig_end number Original selection end line (1-indexed)
---@return number extmark_id The extmark ID for later removal
function M.add_virtual_hint(bufnr, comment_line, orig_start, orig_end)
  local hint_text
  if orig_start == orig_end then
    hint_text = string.format("<- comment for line %d", orig_start)
  else
    hint_text = string.format("<- comment for lines %d:%d", orig_start, orig_end)
  end

  local id = vim.api.nvim_buf_set_extmark(bufnr, ns, comment_line - 1, 0, {
    virt_text = { { hint_text, "Comment" } },
    virt_text_pos = "eol",
  })
  return id
end

---Wrap the current visual selection with [PR]/[/PR] markers.
function M.wrap_selection()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Check if buffer is modifiable
  if not vim.bo[bufnr].modifiable then
    vim.notify("Buffer is not modifiable", vim.log.levels.WARN)
    return
  end

  -- Get visual selection range
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  -- Ensure start <= end (visual selection can go either direction)
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  -- Exit visual mode
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)

  -- Get comment prefix
  local prefix = M.get_comment_prefix()

  -- Get indentation from first selected line
  local first_line = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, start_line, false)[1] or ""
  local indent = first_line:match("^(%s*)") or ""

  -- Build the marker lines
  local open_marker = indent .. prefix .. "[PR]"
  local close_marker = indent .. prefix .. "[/PR]"
  local comment_line_content = indent .. prefix

  -- Insert opening marker above selection
  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, start_line - 1, false, { open_marker })

  -- Selection lines shifted by 1 due to inserted marker
  -- Insert closing marker and comment line after selection
  local new_end_line = end_line + 1
  vim.api.nvim_buf_set_lines(bufnr, new_end_line, new_end_line, false, { close_marker, comment_line_content })

  -- Calculate line numbers after insertion
  local marker_start_line = start_line
  local anchor_start = start_line + 1
  local anchor_end = new_end_line
  local marker_end_line = new_end_line + 1
  local comment_line_num = new_end_line + 2

  -- Apply highlights
  M.apply_block_highlights(bufnr, marker_start_line, marker_end_line, comment_line_num, anchor_start, anchor_end)

  -- Add virtual hint (use original line numbers for the hint)
  local hint_id = M.add_virtual_hint(bufnr, comment_line_num, start_line, end_line)

  -- Set up autocmds to clean up highlights
  local augroup = vim.api.nvim_create_augroup("PrsyncBlockHint", { clear = true })
  -- Remove hint on InsertLeave
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    buffer = bufnr,
    once = true,
    callback = function()
      pcall(vim.api.nvim_buf_del_extmark, bufnr, ns, hint_id)
    end,
  })
  -- Clear all block highlights on text change (handles undo)
  vim.api.nvim_create_autocmd("TextChanged", {
    group = augroup,
    buffer = bufnr,
    once = true,
    callback = function()
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    end,
  })

  -- Position cursor at end of comment line and enter insert mode
  vim.api.nvim_win_set_cursor(0, { comment_line_num, #comment_line_content })
  vim.cmd("startinsert!")
end

---Set up buffer-local visual mode mapping for a specific buffer.
---@param bufnr number Buffer number
function M.setup_buffer_mapping(bufnr)
  local config = require("prsync.config")
  local mapping = config.options.mappings and config.options.mappings.wrap_block

  if not mapping then
    return
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.keymap.set("v", mapping, function()
    M.wrap_selection()
  end, { buffer = bufnr, desc = "Wrap selection with [PR] block" })
end

---Remove buffer-local visual mode mapping for a specific buffer.
---@param bufnr number Buffer number
function M.remove_buffer_mapping(bufnr)
  local config = require("prsync.config")
  local mapping = config.options.mappings and config.options.mappings.wrap_block

  if not mapping then
    return
  end

  pcall(vim.keymap.del, "v", mapping, { buffer = bufnr })
end

---Set up mappings for all loaded buffers (used when offline review is enabled).
function M.setup_all_buffer_mappings()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      M.setup_buffer_mapping(bufnr)
    end
  end
end

---Remove mappings from all loaded buffers (used when offline review is disabled).
function M.remove_all_buffer_mappings()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      M.remove_buffer_mapping(bufnr)
    end
  end
end

---Set up buffer-local visual mode mapping for prsync contexts.
function M.setup_mappings()
  local highlight = require("prsync.highlight")

  local augroup = vim.api.nvim_create_augroup("PrsyncBlockMapping", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function(ev)
      -- Check if we're in a prsync context
      if not highlight.is_prsync_worktree() and not highlight.is_offline_review() then
        M.remove_buffer_mapping(ev.buf)
        return
      end

      M.setup_buffer_mapping(ev.buf)
    end,
  })
end

return M
