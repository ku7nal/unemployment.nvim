local config = require("unemployment.config")
local api = require("unemployment.api")
local solution = require("unemployment.solution")

local M = {}

local function cache_path()
  return vim.fn.stdpath("data") .. "/unemployment/problems.json"
end

local function load_cache()
  local path = cache_path()
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then return nil end

  local ok, cache = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok then return nil end

  if os.time() - cache.fetched_at > config.options.search.cache_ttl then
    return nil
  end

  return cache.problems
end

local function save_cache(problems)
  local path = cache_path()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local cache = {
    fetched_at = os.time(),
    problems = problems,
  }
  vim.fn.writefile({ vim.json.encode(cache) }, path)
end

local function scan_solved()
  local solved = {}
  local dir = config.options.solutions_dir
  local ok, entries = pcall(vim.fn.readdir, dir)
  if not ok then return solved end
  for _, entry in ipairs(entries) do
    local slug = vim.fn.fnamemodify(entry, ":r")
    solved[slug] = true
  end
  return solved
end

local function open_or_fetch_problem(slug)
  local dir = config.options.solutions_dir
  local ext = config.lang_to_ext[config.options.language] or config.options.language
  local filepath = dir .. "/" .. slug .. "." .. ext

  if vim.fn.filereadable(filepath) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    vim.notify("unemployment: Opened '" .. slug .. "'", vim.log.levels.INFO)
  else
    local client = api.new(config.options)
    solution.open(slug, client)
  end
end

local function open_picker(fzf, problems)
  local solved = scan_solved()
  local items = {}
  local slug_map = {}

  for _, p in ipairs(problems) do
    local prefix = p.isPaidOnly and "$ " or "  "
    local solved_mark = solved[p.titleSlug] and "✓" or " "
    local tags = ""
    if p.topicTags and #p.topicTags > 0 then
      local names = {}
      for _, t in ipairs(p.topicTags) do
        table.insert(names, t.name)
      end
      local joined = table.concat(names, ", ")
      if #joined > 50 then
        joined = joined:sub(1, 47) .. "..."
      end
      tags = " - " .. joined
    end
    local display = string.format("%s%s %s. %s [%s]%s",
      prefix, solved_mark, p.questionId, p.title, p.difficulty, tags)
    slug_map[display] = p.titleSlug
    table.insert(items, display)
  end

  if #items == 0 then
    vim.notify("unemployment: No problems found", vim.log.levels.WARN)
    return
  end

  fzf.fzf_exec(items, {
    prompt = "Problems> ",
    fzf_opts = {
      ["--exact"] = "",
    },
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local display = selected[1]
        local slug = slug_map[display]
        if not slug then return end
        local problem = nil
        for _, p in ipairs(problems) do
          if p.titleSlug == slug then
            problem = p
            break
          end
        end
        if problem and problem.isPaidOnly then
          vim.notify("unemployment: '" .. problem.title .. "' is a paid-only problem", vim.log.levels.WARN)
          return
        end
        open_or_fetch_problem(slug)
      end,
    },
  })
end

function M.search_problems()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("unemployment: fzf-lua is required for problem search. Install ibhagwan/fzf-lua.", vim.log.levels.ERROR)
    return
  end

  local problems = load_cache()
  if problems then
    open_picker(fzf, problems)
    return
  end

  vim.notify("unemployment: Fetching problem list...", vim.log.levels.INFO)
  local client = api.new(config.options)
  client:problems_list(function(data, err)
    vim.schedule(function()
      if err then
        vim.notify("unemployment: " .. err, vim.log.levels.ERROR)
        return
      end
      save_cache(data)
      open_picker(fzf, data)
    end)
  end)
end

return M
