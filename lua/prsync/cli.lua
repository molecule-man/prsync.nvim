-- CLI invocation helpers for prsync

local M = {}

---Run a prsync command
---@param cmd string Command name (e.g., "start", "approve")
---@param args table? Additional arguments
---@param callback function? Callback with (err, result)
function M.run(cmd, args, callback)
  -- TODO: implement CLI invocation using vim.system or vim.fn.jobstart
  error("not implemented")
end

return M
