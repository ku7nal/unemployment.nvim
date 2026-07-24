local config = require("unemployment.config")

local M = {}

local function filepath_for_slug(slug, lang)
  local dir = config.options.solutions_dir
  local ext = (lang and config.lang_to_ext[lang]) or config.lang_to_ext[config.options.language] or config.options.language
  return dir .. "/" .. slug .. "." .. ext
end

local function build_message(slug, result)
  local status = result.status or result.status_msg or "Unknown"
  local runtime = (result.status_runtime or result.runtime or "")
  local memory = (result.status_memory or result.memory or "")
  local passed = result.total_correct
  local total = result.total_testcases

  local parts = { slug .. ": " .. status }
  local details = {}
  if runtime ~= "" and runtime ~= "N/A" then
    table.insert(details, runtime)
  end
  if memory ~= "" and memory ~= "N/A" then
    table.insert(details, memory)
  end
  if passed ~= nil and total ~= nil and type(passed) ~= "userdata" then
    table.insert(details, tostring(passed) .. "/" .. tostring(total))
  end
  if #details > 0 then
    parts[1] = parts[1] .. " — " .. table.concat(details, ", ")
  end

  return parts[1]
end

function M.setup()
  if not config.options.git.enabled then return end

  local dir = config.options.solutions_dir
  vim.fn.mkdir(dir, "p")

  if vim.fn.isdirectory(dir .. "/.git") == 1 then return end

  vim.system({ "git", "-C", dir, "init" }, { text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        config.notify("git init failed: " .. (obj.stderr or ""), vim.log.levels.ERROR)
        return
      end

      local gitignore = dir .. "/.gitignore"
      if vim.fn.filereadable(gitignore) == 0 then
        vim.fn.writefile({ "a.out", "*.out", "*.dSYM/", "__pycache__/", ".DS_Store" }, gitignore)
      end

      config.notify("Initialized git repo in " .. dir, vim.log.levels.INFO)
    end)
  end)

  vim.system({ "git", "-C", dir, "config", "user.name" }, { text = true }, function(obj)
    if obj.code ~= 0 or vim.trim(obj.stdout or "") == "" then
      vim.system({ "git", "-C", dir, "config", "user.name", "unemployment.nvim" })
    end
  end)

  vim.system({ "git", "-C", dir, "config", "user.email" }, { text = true }, function(obj)
    if obj.code ~= 0 or vim.trim(obj.stdout or "") == "" then
      vim.system({ "git", "-C", dir, "config", "user.email", "unemployment@nvim" })
    end
  end)
end

function M.commit(slug, result, lang)
  if not config.options.git.enabled then return end
  if not result then return end

  local status = (result.status or result.status_msg or ""):lower()
  if status ~= "accepted" then return end

  local dir = config.options.solutions_dir
  local filepath = filepath_for_slug(slug, lang)

  if vim.fn.filereadable(filepath) ~= 1 then
    config.notify("File not found for commit: " .. filepath, vim.log.levels.WARN)
    return
  end

  local msg = build_message(slug, result)

  vim.system({ "git", "-C", dir, "add", "--", filepath }, { text = true }, function(add_obj)
    if add_obj.code ~= 0 then
      vim.schedule(function()
        config.notify("git add failed: " .. (add_obj.stderr or ""), vim.log.levels.ERROR)
      end)
      return
    end

    vim.system({ "git", "-C", dir, "diff", "--cached", "--quiet", "--", filepath }, { text = true }, function(diff_obj)
      if diff_obj.code == 0 then return end

      vim.system({ "git", "-C", dir, "commit", "-m", msg }, { text = true }, function(commit_obj)
        vim.schedule(function()
          if commit_obj.code ~= 0 then
            config.notify("git commit failed: " .. (commit_obj.stderr or ""), vim.log.levels.ERROR)
          end
        end)
      end)
    end)
  end)
end

function M.log(slug)
  if not config.options.git.enabled then return end

  local dir = config.options.solutions_dir
  local filepath = filepath_for_slug(slug)

  vim.system({ "git", "-C", dir, "log", "--oneline", "-10", "--", filepath }, { text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        config.notify("git log failed: " .. (obj.stderr or ""), vim.log.levels.ERROR)
        return
      end

      local out = vim.trim(obj.stdout or "")
      if out == "" then
        config.notify("No git history for '" .. slug .. "'", vim.log.levels.WARN)
        return
      end

      config.notify("History for " .. slug .. ":\n" .. out, vim.log.levels.INFO)
    end)
  end)
end

return M
