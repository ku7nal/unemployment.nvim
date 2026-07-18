local config = require("unemployment.config")

local function check()
  vim.health.start("unemployment.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
  vim.health.ok("Neovim >= 0.10")
  else
  vim.health.error("Neovim >= 0.10 required (vim.system)")
  end

  local curl = vim.fn.executable("curl")
  if curl == 1 then
  vim.health.ok("curl found")
  else
  vim.health.error("curl not found — required for API calls")
  end

  if not config.initialized then
  vim.health.warn("setup() has not been called — add require('unemployment').setup({...}) to your config")
  return
  end

  if config.options.session_cookie ~= "" then
  vim.health.ok("LEETCODE_SESSION cookie is set")
  else
  vim.health.warn("LEETCODE_SESSION cookie is empty — :Dryrun and :DrySubmit will fail")
  end

  if config.options.csrf_token ~= "" then
  vim.health.ok("csrftoken cookie is set")
  else
  vim.health.warn("csrftoken cookie is empty — :Dryrun and :DrySubmit will fail")
  end

  local dir = config.options.solutions_dir
  if dir and dir ~= "" then
  local ok = vim.fn.mkdir(dir, "p")
  if ok == 1 or ok == 0 then
    vim.health.ok("Solutions dir: " .. dir)
  else
    vim.health.error("Cannot create solutions dir: " .. dir)
  end
  else
  vim.health.warn("solutions_dir not configured")
  end
end

return { check = check }
