-- prsync.nvim: Neovim integration for PR review workflow

local M = {}

function M.setup(opts)
  require("prsync.config").setup(opts)

  local commands = require("prsync.commands")
  vim.api.nvim_create_user_command("PrsyncStart", commands.start, {})
  vim.api.nvim_create_user_command("PrsyncApprove", commands.approve, {})
  vim.api.nvim_create_user_command("PrsyncComment", commands.comment, {})
  vim.api.nvim_create_user_command("PrsyncReject", commands.reject, {})
  vim.api.nvim_create_user_command("PrsyncOfflineReview", commands.offline_review, { nargs = "?" })
  vim.api.nvim_create_user_command("PrsyncExport", commands.export, {})

  require("prsync.highlight").setup_autocmds()
end

return M
