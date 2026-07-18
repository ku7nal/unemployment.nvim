local M = {}

M.defaults = {
  session_cookie = "",
  csrf_token = "",
  solutions_dir = vim.fn.expand("~/leetcode"),
  language = "python3",
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
  kotlin = "kotlin",
  ruby = "ruby",
  scala = "scala",
  php = "php",
  dart = "dart",
  racket = "racket",
  erlang = "erlang",
  elixir = "elixir",
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

return M
