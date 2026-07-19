# unemployment.nvim

LeetCode submit + test + fuzzy search from Neovim, no fluff.

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
| `:DrySearch {slug}` | Fetch problem template and open in a new buffer |
| `:Dryrun` | Run sample tests on the current buffer |
| `:DrySubmit` | Submit the current buffer's solution |
| `:DryProblems` | Fuzzy-search problems via fzf-lua |
| `:DryLog` | Show git history for current problem |

## Keymaps

| Key | Description |
|---|---|
| `<leader>lp` | Search problems via fzf-lua |
| `<leader>lt` | Run sample tests |
| `<leader>ls` | Submit current buffer |
| `<leader>ll` | Git log for current problem |

Leader prefix `l` is configurable via `keys.leader`.

## Configuration

```lua
require("unemployment").setup({
  session_cookie = "",            -- required: LEETCODE_SESSION cookie
  csrf_token = "",                -- required: csrftoken cookie
  solutions_dir = "~/leetcode",   -- where problem files are saved
  language = "cpp",               -- default language for templates
  poll_interval = 500,            -- ms between submission poll attempts
  poll_timeout = 90000,           -- ms before giving up on polling
  keys = { leader = "l" },       -- leader prefix for keymaps
  git = { enabled = true },       -- auto-init repo + commit accepted
  search = { cache_ttl = 86400 }, -- seconds before refetching problem list
})
```

## Features

- **GraphQL API client** — fetches problem data, code snippets, and test cases
- **Code templates** — inserts the LeetCode starter code for your chosen language
- **Run tests** — sends sample test cases and polls for results
- **Submit** — submits solution and shows pass/fail with runtime & memory
- **Fuzzy search** — browse all LeetCode problems via fzf-lua with solved/paid indicators
- **Auto git** — auto-initializes a git repo in `solutions_dir` and commits accepted solutions
- **Language auto-detection** — recognizes language from file extension when re-opening saved files
- **Problem caching** — caches problem list to avoid repeated fetches
- **`:checkhealth`** support via `unemployment.health`

## Dependencies

- Neovim 0.10+ (for `vim.system`)
- `curl`
- `fzf-lua` (optional — only needed for `:DryProblems` / `<leader>lp`)

## Project Structure

```
lua/unemployment/
  init.lua       — setup(), commands, keymaps
  config.lua     — defaults, user config merge, language maps
  api.lua        — GraphQL + REST client via curl
  solution.lua   — open, test, submit, poll logic
  search.lua     — problem cache + fzf-lua picker
  view.lua       — result display
  git.lua        — auto-init, auto-commit, git log
  health.lua     — :checkhealth integration
```
