-- CLI invocation helpers for prsync

local M = {}

---Run a prsync command synchronously
---@param cmd string Command name (e.g., "start", "approve", "prs")
---@param args table? Additional arguments
---@return table|nil result Parsed JSON result or nil on error
---@return string|nil error Error message or nil on success
function M.run(cmd, args)
  local config = require("prsync.config")
  args = args or {}

  local cmd_parts = { config.options.cli_path, "-yes", cmd }
  for _, arg in ipairs(args) do
    table.insert(cmd_parts, tostring(arg))
  end

  local cmd_str = table.concat(cmd_parts, " ")
  local output = vim.fn.system(cmd_str)
  local exit_code = vim.v.shell_error

  if exit_code ~= 0 then
    local err_msg = output:gsub("^%s*(.-)%s*$", "%1")
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

return M
