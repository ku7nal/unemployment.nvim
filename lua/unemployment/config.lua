local M = {}

M.defaults = {
  session_cookie = "",
  csrf_token = "",
  solutions_dir = "~/leetcode",
  language = "python3",
  poll_interval = 500,
  poll_timeout = 90000,
  keys = {
    leader = "l",
  },
  git = {
    enabled = true,
  },
  search = {
    cache_ttl = 86400,
  },
}

M.ext_to_lang = {
  py = "python3",
  js = "javascript",
  ts = "typescript",
  java = "java",
  cpp = "cpp",
  c = "c",
  cs = "csharp",
  go = "golang",
  rs = "rust",
  swift = "swift",
  kt = "kotlin",
  rb = "ruby",
  scala = "scala",
  php = "php",
  dart = "dart",
  rkt = "racket",
  erl = "erlang",
  ex = "elixir",
}

M.lang_to_ext = {}
for lang, ext in pairs(M.ext_to_lang) do
  M.lang_to_ext[ext] = lang
end
M.lang_to_ext["python3"] = "py"

M.lang_to_ft = {
  python3 = "python",
  python = "python",
  javascript = "javascript",
  typescript = "typescript",
  java = "java",
  cpp = "cpp",
  c = "c",
  csharp = "cs",
  golang = "go",
  rust = "rust",
  swift = "swift",
  kt = "kotlin",
  ruby = "ruby",
  scala = "scala",
  php = "php",
  dart = "dart",
  racket = "racket",
  erlang = "erlang",
  elixir = "elixir",
}

M.options = {}
M.initialized = false

local function validate(opts)
  local errors = {}
  if opts.session_cookie == "" then
    table.insert(errors, "session_cookie is empty")
  end
  if opts.csrf_token == "" then
    table.insert(errors, "csrf_token is empty")
  end
  return errors
end

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  M.options.solutions_dir = vim.fn.expand(M.options.solutions_dir)
  M.initialized = true

  local errs = validate(M.options)
  if #errs > 0 then
    vim.notify("unemployment: Config warnings:\n" .. table.concat(errs, "\n"), vim.log.levels.WARN)
  end
end

return M
