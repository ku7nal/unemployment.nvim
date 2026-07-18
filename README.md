# unemployment.nvim

LeetCode submit + test from Neovim, no fluff.

## Requirements

- Neovim 0.10+
- `curl`
- LeetCode session cookie (see Setup)

## Installation

### lazy.nvim

```lua
{
  "unemployment.nvim",
  dir = "~/code/unemployment",
  config = function()
    require("unemployment").setup({
      session_cookie = os.getenv("LEETCODE_SESSION") or "",
      csrf_token = os.getenv("LEETCODE_CSRF") or "",
      solutions_dir = "~/leetcode",
      language = "python3",
    })
  end,
}
```

### packer.nvim

```lua
use {
  "~/code/unemployment",
  config = function()
    require("unemployment").setup({
      session_cookie = os.getenv("LEETCODE_SESSION") or "",
      csrf_token = os.getenv("LEETCODE_CSRF") or "",
      solutions_dir = "~/leetcode",
      language = "python3",
    })
  end,
}
```

## Setup

1. Open LeetCode in your browser and log in.
2. Open DevTools → Application → Cookies → `leetcode.com`.
3. Copy the value of `LEETCODE_SESSION` and `csrftoken`.
4. Set them in config or as env vars:

```bash
export LEETCODE_SESSION="eyJ..."
export LEETCODE_CSRF="abc123"
```

## Commands

| Command | Description |
|---|---|
| `:DrySearch two-sum` | Fetch problem template and open in a new buffer |
| `:Dryrun` | Run sample tests on the current buffer |
| `:DrySubmit` | Submit the current buffer's solution |

## Configuration

```lua
require("unemployment").setup({
  session_cookie = "",            -- required: LEETCODE_SESSION cookie
  csrf_token = "",                -- required: csrftoken cookie
  solutions_dir = "~/leetcode",   -- where problem files are saved
  language = "python3",           -- default language for templates
})
```

## Project Structure

```
lua/unemployment/
  init.lua       — setup(), command definitions
  config.lua     — defaults and user config merge
  api.lua        — GraphQL client via vim.system() + curl
  view.lua       — floating window for submission results
  solution.lua   — open, test, submit logic
```
