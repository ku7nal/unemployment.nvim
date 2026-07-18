local view = {}

function view.show_result(data)
  local lines = {}
  local status = data.status or "Unknown"
  local passed = data.total_correct
  local total = data.total_testcases
  local runtime = data.status_runtime or data.runtime or "N/A"
  local memory = data.status_memory or data.memory or "N/A"

  local status_icon = status == "Accepted" and "✓" or "✗"
  table.insert(lines, "  " .. status_icon .. " " .. status)
  table.insert(lines, "")
  if passed and total then
  table.insert(lines, "  Tests:  " .. passed .. " / " .. total .. " passed")
  end
  table.insert(lines, "  Runtime: " .. runtime)
  table.insert(lines, "  Memory:  " .. memory)
  if data.compare_result and data.compare_result ~= "" then
  table.insert(lines, "")
  table.insert(lines, "  Compare: " .. data.compare_result)
  end
  if data.code_output and data.code_output ~= "" then
  table.insert(lines, "")
  table.insert(lines, "  Output:")
  for _, line in ipairs(vim.split(data.code_output, "\n", { plain = true })) do
    table.insert(lines, "    " .. line)
  end
  end
  if data.expected_formatted and data.expected_formatted ~= "" then
  table.insert(lines, "")
  table.insert(lines, "  Expected:")
  for _, line in ipairs(vim.split(data.expected_formatted, "\n", { plain = true })) do
    table.insert(lines, "    " .. line)
  end
  end

  local width = 72
  local height = math.min(#lines + 4, 30)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

  local win_opts = {
  relative = "editor",
  width = width,
  height = height,
  col = math.floor((vim.o.columns - width) / 2),
  row = math.floor((vim.o.lines - height) / 2),
  style = "minimal",
  border = "rounded",
  title = " unemployment.nvim ",
  title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_win_set_option(win, "winhl", "Normal:NormalFloat")

  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":q<CR>", { noremap = true, silent = true })

  vim.api.nvim_create_autocmd("BufLeave", {
  buffer = buf,
  once = true,
  callback = function()
    pcall(vim.api.nvim_win_close, win, true)
  end,
  })
end

return view
