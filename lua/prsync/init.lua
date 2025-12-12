-- prsync.nvim: Neovim integration for PR review workflow

local M = {}

function M.setup(opts)
  require("prsync.config").setup(opts)

  local commands = require("prsync.commands")
  vim.api.nvim_create_user_command("PrsyncStart", commands.start, {})
  vim.api.nvim_create_user_command("PrsyncApprove", commands.approve, {})
end

return M
