local api = {}

local PROBLEMS_LIST_QUERY = [[
query problemsetQuestionList($categorySlug: String, $limit: Int, $skip: Int, $filters: QuestionListFilterInput) {
  problemsetQuestionList: questionList(
    categorySlug: $categorySlug
    limit: $limit
    skip: $skip
    filters: $filters
  ) {
    total: totalNum
    questions: data {
      acRate
      difficulty
      questionId
      isPaidOnly
      title
      titleSlug
      topicTags {
        name
        id
        slug
      }
    }
  }
}
]]

local QUESTION_DATA_QUERY = [[
query questionData($titleSlug: String!) {
  question(titleSlug: $titleSlug) {
    questionId
    title
    titleSlug
    codeSnippets {
      lang
      langSlug
      code
    }
    sampleTestCase
    metaData
  }
}
]]

function api.new(cfg)
  return setmetatable({
  base_url = "https://leetcode.com",
  session_cookie = cfg.session_cookie,
  csrf_token = cfg.csrf_token,
  }, { __index = api })
end

local static_headers = {
  "Content-Type: application/json",
  "Origin: https://leetcode.com",
  "x-requested-with: XMLHttpRequest",
  "User-Agent: Mozilla/5.0",
}

local function build_cmd(method, url, body, session_cookie, csrf_token, referer)
  local cmd = { "curl", "-s", "-X", method, "--max-time", "30" }

  for _, h in ipairs(static_headers) do
    table.insert(cmd, "-H")
    table.insert(cmd, h)
  end
  table.insert(cmd, "-H")
  table.insert(cmd, "Cookie: LEETCODE_SESSION=" .. session_cookie .. "; csrftoken=" .. csrf_token)
  table.insert(cmd, "-H")
  table.insert(cmd, "x-csrftoken: " .. csrf_token)
  table.insert(cmd, "-H")
  table.insert(cmd, "Referer: " .. (referer or "https://leetcode.com/"))
  table.insert(cmd, url)
  if body then
    table.insert(cmd, "--data-raw")
    table.insert(cmd, body)
  end
  return cmd
end

local function request(method, url, body, session_cookie, csrf_token, callback, referer)
  if session_cookie == "" or csrf_token == "" then
  callback(nil, "Auth required. Set session_cookie and csrf_token in setup()")
  return
  end

  local cmd = build_cmd(method, url, body, session_cookie, csrf_token, referer)

  vim.system(cmd, { text = true }, function(obj)
  if obj.code == nil or obj.code ~= 0 then
    local detail = obj.stderr and obj.stderr ~= "" and (" (" .. obj.stderr:gsub("%s+", " "):sub(1, 80) .. ")") or ""
    if obj.code == 28 then
    callback(nil, "Request timed out after 30s" .. detail)
    else
    callback(nil, "curl failed (exit " .. (obj.code or "?") .. ")" .. detail)
    end
    return
  end

  local raw = obj.stdout
  if not raw or raw == "" then
    callback(nil, "empty response from server")
    return
  end

  local ok, data = pcall(vim.json.decode, raw)
  if not ok then
    if body:find("<title>403 Forbidden</title>") then
    callback(nil, "403 Forbidden — session cookie may be expired")
    elseif body:find("<title>") then
    callback(nil, "server returned HTML instead of JSON (likely auth issue)")
    else
    callback(nil, "unexpected response format")
    end
    return
  end

  if data.errors then
    local msgs = {}
    for _, e in ipairs(data.errors) do
    table.insert(msgs, e.message or "unknown error")
    end
    callback(nil, table.concat(msgs, "; "))
    return
  end

  callback(data, nil)
  end)
end

local DAILY_QUERY = [[
query activeDailyCodingChallengeQuestion {
  activeDailyCodingChallengeQuestion {
    date
    link
    question {
      acRate
      difficulty
      questionId
      isPaidOnly
      title
      titleSlug
      topicTags {
        name
        id
        slug
      }
    }
  }
}
]]

function api:daily_challenge(callback)
  local body = vim.json.encode({ query = DAILY_QUERY, variables = {} })
  request("POST", self.base_url .. "/graphql", body,
    self.session_cookie, self.csrf_token, callback,
    "https://leetcode.com/")
end

function api:question_data(slug, callback)
  local body = vim.json.encode({ query = QUESTION_DATA_QUERY, variables = { titleSlug = slug } })
  request("POST", self.base_url .. "/graphql", body,
  self.session_cookie, self.csrf_token, callback,
  "/problems/" .. slug .. "/")
end

function api:run_test(slug, question_id, lang, code, test_cases, callback)
  local body = vim.json.encode({
  data_input = test_cases,
  lang = lang,
  question_id = tonumber(question_id),
  typed_code = code,
  })
  request("POST", self.base_url .. "/problems/" .. slug .. "/interpret_solution/", body,
  self.session_cookie, self.csrf_token, callback,
  "/problems/" .. slug .. "/")
end

function api:submit(slug, question_id, lang, code, callback)
  local body = vim.json.encode({
  lang = lang,
  question_id = tonumber(question_id),
  typed_code = code,
  titleSlug = slug,
  })
  request("POST", self.base_url .. "/problems/" .. slug .. "/submit/", body,
  self.session_cookie, self.csrf_token, callback,
  "/problems/" .. slug .. "/")
end

function api:check_submission(id, callback)
  request("GET", self.base_url .. "/submissions/detail/" .. id .. "/check/", nil,
  self.session_cookie, self.csrf_token, callback)
end

function api:problems_list(callback)
  local all_problems = {}
  local limit = 100
  local skip = 0
  local total = nil

  local function fetch_page()
    local variables = {
      categorySlug = "",
      limit = limit,
      skip = skip,
      filters = vim.empty_dict(),
    }
    local body = vim.json.encode({ query = PROBLEMS_LIST_QUERY, variables = variables })
    request("POST", self.base_url .. "/graphql", body,
    self.session_cookie, self.csrf_token, function(data, err)
    if err then
      callback(nil, err)
      return
    end

    if not data.data or not data.data.problemsetQuestionList then
      callback(nil, "Unexpected response format from problem list query")
      return
    end

    local result = data.data.problemsetQuestionList
    for _, q in ipairs(result.questions) do
      table.insert(all_problems, q)
    end

    if total == nil then
      total = result.total
    end

    skip = skip + limit
    if skip < total then
      fetch_page()
    else
      callback(all_problems, nil)
    end
    end)
  end

  fetch_page()
end

return api
