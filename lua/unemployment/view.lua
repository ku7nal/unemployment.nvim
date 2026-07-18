local view = {}

local function to_str(v)
  if type(v) == "table" then
    local parts = {}
    for _, item in ipairs(v) do
      table.insert(parts, tostring(item))
    end
    return #parts > 0 and table.concat(parts, "\n") or ""
  end
  if type(v) == "userdata" then return "" end
  return tostring(v)
end

local function first_line(s)
  s = to_str(s)
  local idx = s:find("\n")
  return idx and s:sub(1, idx - 1) or s
end

function view.show_result(data)
  local status = data.status or data.status_msg or "Unknown"
  local icon = status == "Accepted" and "✓" or "✗"
  local msg

  local compile_err = data.full_compile_error
  if compile_err and to_str(compile_err) ~= "" then
    msg = icon .. " " .. status .. " | " .. first_line(compile_err)
    vim.notify(msg, vim.log.levels.ERROR)
    return
  end

  local passed = data.total_correct
  local total = data.total_testcases
  local runtime = to_str(data.status_runtime or data.runtime or "")
  local memory = to_str(data.status_memory or data.memory or "")

  if passed and total and type(passed) ~= "userdata" and type(total) ~= "userdata" then
    local parts = { icon .. " " .. status }
    if runtime ~= "" and runtime ~= "N/A" then table.insert(parts, runtime) end
    if memory ~= "" and memory ~= "N/A" then table.insert(parts, memory) end
    table.insert(parts, tostring(passed) .. "/" .. tostring(total))
    msg = table.concat(parts, " | ")
  elseif data.run_success ~= nil then
    local output = first_line(data.code_answer or data.code_output or "")
    local expected = first_line(data.correct_answer or data.expected_formatted or "")
    local parts = { icon .. " " .. status }
    if output ~= "" then table.insert(parts, "Got: " .. output) end
    if expected ~= "" then table.insert(parts, "Expected: " .. expected) end
    msg = table.concat(parts, " | ")
  else
    msg = icon .. " " .. status
  end

  local level = status == "Accepted" and vim.log.levels.INFO or vim.log.levels.WARN
  vim.notify(msg, level)
end

return view
