local config = require("unemployment.config")
local view = require("unemployment.view")

local solution = {}

function solution.open(slug, client)
  vim.notify("unemployment: Fetching problem '" .. slug .. "'...", vim.log.levels.INFO)

  client:question_data(slug, function(data, err)
  if err then
    vim.notify("unemployment: " .. err, vim.log.levels.ERROR)
    return
  end

  local question = data.data.question
  local question_id = question.questionId
  local snippets = question.codeSnippets

  local code = ""
  local lang_slug = config.options.language
  for _, s in ipairs(snippets) do
    if s.langSlug == lang_slug then
    code = s.code
    break
    end
  end

  if code == "" then
    vim.notify("unemployment: No template found for language '" .. lang_slug .. "'", vim.log.levels.ERROR)
    return
  end

  local ext = config.lang_to_ext[lang_slug] or lang_slug
  local dir = config.options.solutions_dir
  vim.fn.mkdir(dir, "p")
  local filepath = dir .. "/" .. slug .. "." .. ext

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(code, "\n", { plain = true }))
  vim.api.nvim_buf_set_name(buf, filepath)
  vim.api.nvim_set_current_buf(buf)
  local ft = config.lang_to_ft[lang_slug] or lang_slug
  vim.api.nvim_buf_set_option(buf, "filetype", ft)
  vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")

  vim.bo[buf].modified = false

  vim.b[buf].unemployment_slug = slug
  vim.b[buf].unemployment_question_id = question_id
  vim.b[buf].unemployment_lang = lang_slug

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
    vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1), filepath)
    vim.bo[buf].modified = false
    vim.notify("unemployment: Saved to " .. filepath, vim.log.levels.INFO)
    end,
  })

  vim.notify("unemployment: Opened '" .. question.title .. "'", vim.log.levels.INFO)
  end)
end

local function problem_info_from_buf()
  local buf = vim.api.nvim_get_current_buf()

  if vim.b[buf].unemployment_slug then
  return {
    slug = vim.b[buf].unemployment_slug,
    question_id = vim.b[buf].unemployment_question_id,
    lang = vim.b[buf].unemployment_lang,
  }
  end

  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then
  return nil, "Buffer has no file path. Use LeetCodeOpen first."
  end

  local filename = vim.fn.fnamemodify(path, ":t")
  local slug = vim.fn.fnamemodify(filename, ":r")
  local ext = vim.fn.fnamemodify(filename, ":e")
  local lang = config.ext_to_lang[ext]

  if not lang then
  return nil, "Unknown language for file extension '" .. ext .. "'"
  end

  return { slug = slug, question_id = nil, lang = lang }
end

local function get_code()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1)
  return table.concat(lines, "\n")
end

local function poll_submission(id, client, callback, interval, elapsed)
  interval = interval or 1000
  elapsed = elapsed or 0

  if elapsed > 60000 then
  callback(nil, "Timed out waiting for submission result")
  return
  end

  vim.defer_fn(function()
  client:check_submission(id, function(data, err)
    if err then
    callback(nil, err)
    return
    end

    if data.state == "SUCCESS" then
    callback(data, nil)
    else
    poll_submission(id, client, callback, interval, elapsed + interval)
    end
  end)
  end, interval)
end

function solution.test(client)
  vim.notify("unemployment: Running tests...", vim.log.levels.INFO)

  local info, err = problem_info_from_buf()
  if not info then
  vim.notify("unemployment: " .. err, vim.log.levels.ERROR)
  return
  end

  local code = get_code()
  local buf = vim.api.nvim_get_current_buf()

  client:question_data(info.slug, function(data, err)
  if err then
    vim.notify("unemployment: " .. err, vim.log.levels.ERROR)
    return
  end

  local question = data.data.question
  local question_id = question.questionId
  local test_cases = question.sampleTestCase or ""

  vim.b[buf].unemployment_question_id = question_id

  client:run_test(info.slug, question_id, info.lang, code, test_cases, function(data, err)
    if err then
    vim.notify("unemployment: " .. err, vim.log.levels.ERROR)
    return
    end
    if not data or not data.data or not data.data.runCode then
    vim.notify("unemployment: Unexpected response from runCode", vim.log.levels.ERROR)
    return
    end
    local submission_id = data.data.runCode.submissionId
    poll_submission(submission_id, client, function(result, poll_err)
    if poll_err then
      vim.notify("unemployment: " .. poll_err, vim.log.levels.ERROR)
      return
    end
    view.show_result(result)
    end)
  end)
  end)
end

function solution.submit(client)
  vim.notify("unemployment: Submitting solution...", vim.log.levels.INFO)

  local info, err = problem_info_from_buf()
  if not info then
  vim.notify("unemployment: " .. err, vim.log.levels.ERROR)
  return
  end

  local code = get_code()

  local function do_submit(question_id)
  client:submit(info.slug, question_id, info.lang, code, function(data, err)
    if err then
    vim.notify("unemployment: " .. err, vim.log.levels.ERROR)
    return
    end
    if not data or not data.data or not data.data.submitCode then
    vim.notify("unemployment: Unexpected response from submitCode", vim.log.levels.ERROR)
    return
    end
    local submission_id = data.data.submitCode.submissionId
    poll_submission(submission_id, client, function(result, poll_err)
    if poll_err then
      vim.notify("unemployment: " .. poll_err, vim.log.levels.ERROR)
      return
    end
    view.show_result(result)
    end)
  end)
  end

  if info.question_id then
  do_submit(info.question_id)
  else
  client:question_data(info.slug, function(data, err)
    if err then
    vim.notify("unemployment: " .. err, vim.log.levels.ERROR)
    return
    end
    local qid = data.data.question.questionId
    local buf = vim.api.nvim_get_current_buf()
    vim.b[buf].unemployment_question_id = qid
    do_submit(qid)
  end)
  end
end

return solution
