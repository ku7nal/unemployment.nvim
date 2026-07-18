local api = {}

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
  cmd[#cmd + 1] = "-H"
  cmd[#cmd + 1] = h
  end
  cmd[#cmd + 1] = "-H"
  cmd[#cmd + 1] = "Cookie: LEETCODE_SESSION=" .. session_cookie .. "; csrftoken=" .. csrf_token
  cmd[#cmd + 1] = "-H"
  cmd[#cmd + 1] = "x-csrftoken: " .. csrf_token
  cmd[#cmd + 1] = "-H"
  cmd[#cmd + 1] = "Referer: " .. (referer or "https://leetcode.com/")
  cmd[#cmd + 1] = url
  if body then
  cmd[#cmd + 1] = "--data-raw"
  cmd[#cmd + 1] = body
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

  local body = obj.stdout
  if not body or body == "" then
    callback(nil, "empty response from server")
    return
  end

  local ok, data = pcall(vim.json.decode, body)
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

return api
