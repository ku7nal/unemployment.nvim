local config = require("unemployment.config")
local api = require("unemployment.api")
local solution = require("unemployment.solution")
local search = require("unemployment.search")
local git = require("unemployment.git")

local M = {}

local function require_setup()
  if not config.initialized then
  config.notify("Call setup() first: require('unemployment').setup({...})", vim.log.levels.ERROR)
  return false
  end
  return true
end

local function on_submit_complete(result)
  local slug, _ = solution.current_slug()
  local buf = vim.api.nvim_get_current_buf()
  local lang = vim.api.nvim_buf_is_valid(buf) and vim.b[buf].unemployment_lang or nil
  if slug then git.commit(slug, result, lang) end
end

function M.setup(opts)
  config.setup(opts)

  if config.options.session_cookie == "" or config.options.csrf_token == "" then
  config.notify("session_cookie and/or csrf_token not set. :Dryrun/:DrySubmit will not work until configured.", vim.log.levels.WARN)
  end

  git.setup()

  local client = api.new(config.options)

  vim.api.nvim_create_user_command("DrySearch", function(args)
  if not require_setup() then return end
  local parts = vim.split(args.args, "%s+")
  local slug = parts[1]
  local lang = parts[2]
  solution.open(slug, client, lang)
  end, {
  nargs = "+",
  complete = function(ArgLead, CmdLine, CursorPos)
    local before_cursor = CmdLine:sub(1, CursorPos)
    local parts = vim.split(before_cursor, "%s+")
    if #parts <= 2 then return {} end
    return vim.tbl_filter(function(l) return l:find(ArgLead) ~= nil end, config.lang_slugs)
  end,
  desc = "Fetch and open a LeetCode problem. Usage: :DrySearch {slug} [lang]",
  })

  vim.api.nvim_create_user_command("Dryrun", function()
  if not require_setup() then return end
  solution.test(client)
  end, { desc = "Run sample tests on current buffer" })

  vim.api.nvim_create_user_command("DrySubmit", function()
  if not require_setup() then return end
  solution.submit(client, on_submit_complete)
  end, { desc = "Submit current buffer to LeetCode" })

  vim.api.nvim_create_user_command("DryProblems", function()
  if not require_setup() then return end
  search.search_problems()
  end, { desc = "Search LeetCode problems with fzf-lua" })

  vim.api.nvim_create_user_command("DryLang", function(args)
  if not require_setup() then return end
  solution.switch_lang(client, args.args)
  end, {
  nargs = 1,
  complete = function(ArgLead)
    return vim.tbl_filter(function(l) return l:find(ArgLead) ~= nil end, config.lang_slugs)
  end,
  desc = "Switch current buffer's programming language",
  })

  local p = config.options.keys.leader
  vim.keymap.set("n", "<leader>" .. p .. "p", function()
    if not require_setup() then return end
    search.search_problems()
  end, { desc = "Problems: search LeetCode" })

  vim.keymap.set("n", "<leader>" .. p .. "t", function()
    if not require_setup() then return end
    solution.test(client)
  end, { desc = "Test: run sample cases" })

  vim.keymap.set("n", "<leader>" .. p .. "s", function()
    if not require_setup() then return end
    solution.submit(client, on_submit_complete)
  end, { desc = "Submit: full submission" })

  vim.api.nvim_create_user_command("DryLog", function()
  if not require_setup() then return end
  local slug, err = solution.current_slug()
  if not slug then
    config.notify(err, vim.log.levels.ERROR)
    return
  end
  git.log(slug)
  end, { desc = "Show git history for current problem" })

  vim.keymap.set("n", "<leader>" .. p .. "l", function()
    if not require_setup() then return end
    local slug, err = solution.current_slug()
    if not slug then
      config.notify(err, vim.log.levels.ERROR)
      return
    end
    git.log(slug)
  end, { desc = "Log: git history for current problem" })
end

M.search_problems = search.search_problems

return M
