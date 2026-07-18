local api = {}

function api.new(config)
  return setmetatable({
  base_url = "https://leetcode.com",
  session_cookie = config.session_cookie,
  csrf_token = config.csrf_token,
  }, { __index = api })
end

function api:_headers()
  return {
  "Content-Type: application/json",
  "Cookie: LEETCODE_SESSION=" .. self.session_cookie,
  "x-csrftoken: " .. self.csrf_token,
  "Referer: https://leetcode.com/",
  "Origin: https://leetcode.com",
  }
end

function api:_request(method, path, body, callback)
  if self.session_cookie == "" or self.csrf_token == "" then
  callback(nil, "session_cookie and csrf_token must be set in setup()")
  return
  end

  local cmd = { "curl", "-s", "-X", method }
  for _, h in ipairs(self:_headers()) do
  cmd[#cmd + 1] = "-H"
  cmd[#cmd + 1] = h
  end
  cmd[#cmd + 1] = self.base_url .. path
  if body then
  cmd[#cmd + 1] = "--data-raw"
  cmd[#cmd + 1] = body
  end

  vim.system(cmd, { text = true }, function(obj)
  if obj.code ~= 0 then
    callback(nil, "curl exit code " .. obj.code .. ": " .. (obj.stderr or "unknown error"))
    return
  end
  if not obj.stdout or obj.stdout == "" then
    callback(nil, "empty response from server")
    return
  end
  local ok, data = pcall(vim.json.decode, obj.stdout)
  if not ok then
    callback(nil, "failed to parse JSON response")
    return
  end
  if data.errors then
    local msg = data.errors[1] and data.errors[1].message or "GraphQL error"
    callback(nil, msg)
    return
  end
  callback(data, nil)
  end)
end

function api:_graphql(query, variables, callback)
  local body = vim.json.encode({ query = query, variables = variables })
  self:_request("POST", "/graphql", body, callback)
end

function api:question_data(slug, callback)
  local query = [[
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
  self:_graphql(query, { titleSlug = slug }, callback)
end

function api:run_test(slug, question_id, lang, code, test_cases, callback)
  local query = [[
  mutation runCode($titleSlug: String!, $lang: String!, $code: String!, $questionId: String!, $testCases: String!) {
    runCode(titleSlug: $titleSlug, lang: $lang, code: $code, questionId: $questionId, testCases: $testCases) {
    submissionId
    }
  }
  ]]
  self:_graphql(query, {
  titleSlug = slug,
  lang = lang,
  code = code,
  questionId = tostring(question_id),
  testCases = test_cases,
  }, callback)
end

function api:submit(slug, question_id, lang, code, callback)
  local query = [[
  mutation submitCode($titleSlug: String!, $lang: String!, $code: String!, $questionId: String!) {
    submitCode(titleSlug: $titleSlug, lang: $lang, code: $code, questionId: $questionId) {
    submissionId
    }
  }
  ]]
  self:_graphql(query, {
  titleSlug = slug,
  lang = lang,
  code = code,
  questionId = tostring(question_id),
  }, callback)
end

function api:check_submission(id, callback)
  self:_request("GET", "/submissions/detail/" .. id .. "/check/", nil, callback)
end

return api
