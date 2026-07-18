local config = require("unemployment.config")
local api = require("unemployment.api")
local solution = require("unemployment.solution")

local M = {}

function M.setup(opts)
  config.setup(opts)

  local client = api.new(config.options)

  vim.api.nvim_create_user_command("DrySearch", function(args)
  solution.open(args.args, client)
  end, { nargs = 1, desc = "Open a LeetCode problem by slug" })

  vim.api.nvim_create_user_command("Dryrun", function()
  solution.test(client)
  end, { desc = "Run sample tests on current solution" })

  vim.api.nvim_create_user_command("DrySubmit", function()
  solution.submit(client)
  end, { desc = "Submit current solution to LeetCode" })
end

return M
