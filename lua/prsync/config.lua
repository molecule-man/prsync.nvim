-- Configuration management for prsync.nvim

local M = {}

M.defaults = {
  cli_path = "prsync",
  mappings = {
    wrap_block = "<leader>pr",
  },
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
