local config = require("unemployment.config")
local view = require("unemployment.view")

local solution = {}

local function get_code()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  return table.concat(lines, "\n")
end

function solution.open(slug, client, lang)
  local dir = config.options.solutions_dir
  vim.fn.mkdir(dir, "p")

  config.notify("Fetching problem '" .. slug .. "'...", vim.log.levels.INFO)

  local lang_slug = lang or config.options.language

  client:question_data(slug, function(data, err)
  vim.schedule(function()
    if err then
    config.notify(err, vim.log.levels.ERROR)
    return
    end

    local question = data.data.question
    local snippets = question.codeSnippets

    local code = ""
    for _, s in ipairs(snippets) do
    if s.langSlug == lang_slug then
      code = s.code
      break
    end
    end

    if code == "" then
    config.notify("No template for '" .. lang_slug .. "'", vim.log.levels.ERROR)
    return
    end

    local ext = config.lang_to_ext[lang_slug] or lang_slug
    local ft = config.lang_to_ft[lang_slug] or lang_slug
    local filepath = dir .. "/" .. slug .. "." .. ext

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(code, "\n", { plain = true }))
    vim.api.nvim_buf_set_name(buf, filepath)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = ft
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].modified = false

    vim.b[buf].unemployment_slug = slug
    vim.b[buf].unemployment_question_id = question.questionId
    vim.b[buf].unemployment_lang = lang_slug
    vim.b[buf].unemployment_test_case = question.sampleTestCase or ""

    vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, true), filepath)
      vim.bo[buf].modified = false
    end,
    })

    config.notify("Opened '" .. question.title .. "'", vim.log.levels.INFO)
  end)
  end)
end

local function problem_info()
  local buf = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return nil, "No valid buffer"
  end

  if vim.b[buf].unemployment_slug then
  return {
    slug = vim.b[buf].unemployment_slug,
    question_id = vim.b[buf].unemployment_question_id,
    test_case = vim.b[buf].unemployment_test_case,
    lang = vim.b[buf].unemployment_lang,
  }
  end

  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then
  return nil, "Use :DrySearch {slug} first to open a problem"
  end

  local filename = vim.fn.fnamemodify(path, ":t")
  local slug = vim.fn.fnamemodify(filename, ":r")
  local ext = vim.fn.fnamemodify(filename, ":e")
  local lang = config.ext_to_lang[ext]

  if not lang then
  return nil, "Unrecognized extension '." .. ext .. "' for LeetCode"
  end

  return { slug = slug, question_id = nil, test_case = nil, lang = lang }
end

function solution.switch_lang(client, lang)
  local info, err = problem_info()
  if not info then
    config.notify(err, vim.log.levels.ERROR)
    return
  end

  local slug = info.slug
  local dir = config.options.solutions_dir

  config.notify("Switching '" .. slug .. "' to " .. lang .. "...", vim.log.levels.INFO)

  client:question_data(slug, function(data, err)
    vim.schedule(function()
      if err then
        config.notify(err, vim.log.levels.ERROR)
        return
      end

      local question = data.data.question
      local snippets = question.codeSnippets

      local code = ""
      for _, s in ipairs(snippets) do
        if s.langSlug == lang then
          code = s.code
          break
        end
      end

      if code == "" then
        config.notify("No template for '" .. lang .. "'", vim.log.levels.ERROR)
        return
      end

      local ext = config.lang_to_ext[lang] or lang
      local ft = config.lang_to_ft[lang] or lang
      local filepath = dir .. "/" .. slug .. "." .. ext

      local buf = vim.api.nvim_get_current_buf()
      if not vim.api.nvim_buf_is_valid(buf) then
        config.notify("No valid buffer", vim.log.levels.ERROR)
        return
      end

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(code, "\n", { plain = true }))
      vim.api.nvim_buf_set_name(buf, filepath)
      vim.bo[buf].filetype = ft
      vim.bo[buf].buftype = "acwrite"
      vim.bo[buf].modified = false

      vim.b[buf].unemployment_lang = lang
      vim.b[buf].unemployment_question_id = question.questionId
      vim.b[buf].unemployment_test_case = question.sampleTestCase or ""

      local existing = vim.api.nvim_get_autocmds({ buffer = buf, event = "BufWriteCmd" })
      for _, au in ipairs(existing) do
        pcall(vim.api.nvim_del_autocmd, au.id)
      end

      vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
          vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, true), filepath)
          vim.bo[buf].modified = false
        end,
      })

      config.notify("Switched to '" .. lang .. "'", vim.log.levels.INFO)
    end)
  end)
end

local function fetch_question(info, client, callback)
  if info.question_id then
  callback(info)
  return
  end

  client:question_data(info.slug, function(data, err)
  vim.schedule(function()
    if err then
    config.notify(err, vim.log.levels.ERROR)
    return
    end
    local q = data.data.question
    local buf = vim.api.nvim_get_current_buf()
    vim.b[buf].unemployment_question_id = q.questionId
    vim.b[buf].unemployment_test_case = q.sampleTestCase or ""
    info.question_id = q.questionId
    info.test_case = q.sampleTestCase or ""
    callback(info)
  end)
  end)
end

local function poll(id, client, callback, elapsed)
  local base = config.options.poll_interval
  local timeout = config.options.poll_timeout
  elapsed = elapsed or 0

  if elapsed >= timeout then
  callback(nil, "Timed out after " .. (timeout / 1000) .. "s")
  return
  end

  local backoff = elapsed < 5000 and base or math.min(base * 2, 2000)
  vim.defer_fn(function()
  client:check_submission(id, function(data, err)
    if err then
    callback(nil, err)
    return
    end
    if data.state == "SUCCESS" then
    callback(data, nil)
    else
    poll(id, client, callback, elapsed + backoff)
    end
  end)
  end, backoff)
end

local function submit_code(desc, fn, info, code, client, on_complete)
  config.notify(desc .. "...", vim.log.levels.INFO)

  fn(info.slug, info.question_id, info.lang, code, function(data, err)
  vim.schedule(function()
    if err then
    config.notify(err, vim.log.levels.ERROR)
    return
    end

    local sid = data.interpret_id or data.submission_id
    if not sid then
    config.notify("Unexpected response", vim.log.levels.ERROR)
    return
    end

    poll(sid, client, function(result, poll_err)
    vim.schedule(function()
      if poll_err then
      config.notify(poll_err, vim.log.levels.ERROR)
      return
      end
      view.show_result(result)
      if on_complete then
      on_complete(result)
      end
    end)
    end)
  end)
  end)
end

function solution.test(client)
  local info, err = problem_info()
  if not info then
  config.notify(err, vim.log.levels.ERROR)
  return
  end

  local code = get_code()

  fetch_question(info, client, function(ready)
  if not ready then return end
  submit_code("Running tests",
    function(slug, qid, lang, code, cb)
    client:run_test(slug, qid, lang, code, info.test_case, cb)
    end, info, code, client)
  end)
end

function solution.submit(client, on_complete)
  local info, err = problem_info()
  if not info then
  config.notify(err, vim.log.levels.ERROR)
  return
  end

  local code = get_code()

  fetch_question(info, client, function(ready)
  if not ready then return end
  submit_code("Submitting",
    function(slug, qid, lang, code, cb)
    client:submit(slug, qid, lang, code, cb)
    end, info, code, client, on_complete)
  end)
end

function solution.current_slug()
  local info, err = problem_info()
  if not info then return nil, err end
  return info.slug
end

function solution.reset(client)
  local info, err = problem_info()
  if not info then
    config.notify(err, vim.log.levels.ERROR)
    return
  end
  solution.switch_lang(client, info.lang)
end

function solution.daily(client)
  config.notify("Fetching daily challenge...", vim.log.levels.INFO)

  client:daily_challenge(function(data, err)
    vim.schedule(function()
      if err then
        config.notify(err, vim.log.levels.ERROR)
        return
      end

      local daily = data.data.activeDailyCodingChallengeQuestion
      local slug = daily.question.titleSlug
      local title = daily.question.title
      local difficulty = daily.question.difficulty

      config.notify("Daily: " .. title .. " [" .. difficulty .. "]", vim.log.levels.INFO)
      solution.open(slug, client)
    end)
  end)
end

function solution.stats()
  local dir = config.options.solutions_dir
  local ok, entries = pcall(vim.fn.readdir, dir)
  if not ok then
    config.notify("Cannot read solutions directory", vim.log.levels.ERROR)
    return
  end

  local by_lang = {}
  local slugs = {}
  local git_count = 0

  for _, entry in ipairs(entries) do
    local ext = vim.fn.fnamemodify(entry, ":e")
    local slug = vim.fn.fnamemodify(entry, ":r")
    if ext and ext ~= "" and slug ~= "" and slug ~= ".gitignore" then
      slugs[slug] = true
      local lang = config.ext_to_lang[ext]
      if lang then
        by_lang[lang] = (by_lang[lang] or 0) + 1
      end
    end
  end

  local attempted = 0
  for _ in pairs(slugs) do attempted = attempted + 1 end

  if config.options.git.enabled then
    local result = vim.system({ "git", "-C", dir, "log", "--oneline" }, { text = true }):wait()
    if result.code == 0 then
      local lines = vim.split(vim.trim(result.stdout or ""), "\n")
      git_count = #lines
      if lines[1] == "" then git_count = 0 end
    end
  end

  local parts = { "Attempted: " .. attempted }
  if git_count > 0 then
    table.insert(parts, "Accepted: " .. git_count)
  end

  local langs = {}
  for lang, count in pairs(by_lang) do
    table.insert(langs, lang .. ": " .. count)
  end
  table.sort(langs)
  if #langs > 0 then
    table.insert(parts, table.concat(langs, " | "))
  end

  config.notify(table.concat(parts, "  "), vim.log.levels.INFO)
end

return solution
