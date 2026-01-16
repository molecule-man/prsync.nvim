-- CLI invocation helpers for prsync

local M = {}

---Run a prsync command synchronously
---@param cmd string Command name (e.g., "start", "approve", "prs")
---@param args table? Command-specific arguments
---@param global_args table? Global flags placed before the command
---@return table|nil result Parsed JSON result or nil on error
---@return string|nil error Error message or nil on success
function M.run(cmd, args, global_args)
  local config = require("prsync.config")
  args = args or {}
  global_args = global_args or {}

  local cmd_parts = { config.options.cli_path, "-yes" }
  for _, arg in ipairs(global_args) do
    table.insert(cmd_parts, tostring(arg))
  end
  table.insert(cmd_parts, cmd)
  for _, arg in ipairs(args) do
    table.insert(cmd_parts, tostring(arg))
  end

  local result = vim.system(cmd_parts, { text = true }):wait()
  local output = result.stdout or ""
  local exit_code = result.code

  if exit_code ~= 0 then
    local err_msg = (result.stderr or ""):gsub("^%s*(.-)%s*$", "%1")
    if err_msg == "" then
      err_msg = output:gsub("^%s*(.-)%s*$", "%1")
    end
    if err_msg == "" then
      err_msg = "command failed with exit code " .. exit_code
    end
    return nil, err_msg
  end

  local has_json = vim.tbl_contains(args, "-format") and vim.tbl_contains(args, "json")
  if has_json then
    local ok, parsed = pcall(vim.json.decode, output)
    if not ok then
      return nil, "failed to parse JSON: " .. tostring(parsed)
    end
    return parsed, nil
  end

  return output, nil
end

---Run a prsync command asynchronously
---@param cmd string Command name (e.g., "start", "approve", "prs")
---@param args table? Command-specific arguments
---@param global_args table? Global flags placed before the command
---@param callback fun(result: table|nil, err: string|nil) Called with parsed result or error
function M.run_async(cmd, args, global_args, callback)
  local config = require("prsync.config")
  args = args or {}
  global_args = global_args or {}

  local cmd_parts = { config.options.cli_path, "-yes" }
  for _, arg in ipairs(global_args) do
    table.insert(cmd_parts, tostring(arg))
  end
  table.insert(cmd_parts, cmd)
  for _, arg in ipairs(args) do
    table.insert(cmd_parts, tostring(arg))
  end

  local has_json = vim.tbl_contains(args, "-format") and vim.tbl_contains(args, "json")

  vim.system(cmd_parts, { text = true }, function(result)
    vim.schedule(function()
      local output = result.stdout or ""
      local exit_code = result.code

      if exit_code ~= 0 then
        local err_msg = (result.stderr or ""):gsub("^%s*(.-)%s*$", "%1")
        if err_msg == "" then
          err_msg = output:gsub("^%s*(.-)%s*$", "%1")
        end
        if err_msg == "" then
          err_msg = "command failed with exit code " .. exit_code
        end
        callback(nil, err_msg)
        return
      end

      if has_json then
        local ok, parsed = pcall(vim.json.decode, output)
        if not ok then
          callback(nil, "failed to parse JSON: " .. tostring(parsed))
          return
        end
        callback(parsed, nil)
        return
      end

      callback(output, nil)
    end)
  end)
end

---Run a prsync command with stdin input
---@param cmd string Command name
---@param stdin_content string Content to pass via stdin
---@param args table? Command-specific arguments
---@param global_args table? Global flags placed before the command
---@return string|nil result Output or nil on error
---@return string|nil error Error message or nil on success
function M.run_with_stdin(cmd, stdin_content, args, global_args)
  local config = require("prsync.config")
  args = args or {}
  global_args = global_args or {}

  local cmd_parts = { config.options.cli_path, "-yes" }
  for _, arg in ipairs(global_args) do
    table.insert(cmd_parts, tostring(arg))
  end
  table.insert(cmd_parts, cmd)
  for _, arg in ipairs(args) do
    table.insert(cmd_parts, tostring(arg))
  end

  local result = vim.system(cmd_parts, { text = true, stdin = stdin_content }):wait()
  local output = result.stdout or ""

  if result.code ~= 0 then
    local err_msg = (result.stderr or ""):gsub("^%s*(.-)%s*$", "%1")
    if err_msg == "" then
      err_msg = output:gsub("^%s*(.-)%s*$", "%1")
    end
    if err_msg == "" then
      err_msg = "command failed with exit code " .. result.code
    end
    return nil, err_msg
  end

  return output, nil
end

return M
