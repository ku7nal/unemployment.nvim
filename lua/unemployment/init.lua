local config = require("unemployment.config")
local api = require("unemployment.api")
local solution = require("unemployment.solution")
local search = require("unemployment.search")

local M = {}

local function require_setup()
  if not config.initialized then
  vim.notify("unemployment: Call setup() first: require('unemployment').setup({...})", vim.log.levels.ERROR)
  return false
  end
  return true
end

function M.setup(opts)
  config.setup(opts)

  if config.options.session_cookie == "" or config.options.csrf_token == "" then
  vim.notify("unemployment: session_cookie and/or csrf_token not set. :Dryrun/:DrySubmit will not work until configured.", vim.log.levels.WARN)
  end

  local client = api.new(config.options)

  vim.api.nvim_create_user_command("DrySearch", function(args)
  if not require_setup() then return end
  solution.open(args.args, client)
  end, { nargs = 1, desc = "Fetch and open a LeetCode problem" })

  vim.api.nvim_create_user_command("Dryrun", function()
  if not require_setup() then return end
  solution.test(client)
  end, { desc = "Run sample tests on current buffer" })

  vim.api.nvim_create_user_command("DrySubmit", function()
  if not require_setup() then return end
  solution.submit(client)
  end, { desc = "Submit current buffer to LeetCode" })

  vim.api.nvim_create_user_command("DryProblems", function()
  if not require_setup() then return end
  search.search_problems()
  end, { desc = "Search LeetCode problems with fzf-lua" })

  local p = config.options.keys.leader
  vim.keymap.set("n", "<leader>" .. p .. "p", function()
    search.search_problems()
  end, { desc = "Problems: search LeetCode" })

  vim.keymap.set("n", "<leader>" .. p .. "t", function()
    if not require_setup() then return end
    solution.test(client)
  end, { desc = "Test: run sample cases" })

  vim.keymap.set("n", "<leader>" .. p .. "s", function()
    if not require_setup() then return end
    solution.submit(client)
  end, { desc = "Submit: full submission" })

end

M.search_problems = search.search_problems

return M
