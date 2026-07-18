# unemployment.nvim — v1 Plan

## Scope (3 commands)

| Command              | Action                                                                 |
|----------------------|-----------------------------------------------------------------------|
| `:LeetCodeOpen {slug}` | Fetch template → open buffer → save to `<solutions_dir>/<slug>.<ext>` |
| `:LeetCodeTest`      | Read current buffer → submit to LeetCode's test runner → poll → show results in float |
| `:LeetCodeSubmit`    | Read current buffer → submit for full eval → poll → show results in float |

## Problem Detection

Filename like `two-sum.py` → slug = `two-sum`, language from extension.

## Plugin Structure

```
lua/unemployment/
  init.lua       — setup(), command definitions, keybinds
  config.lua     — default config + merge
  api.lua        — GraphQL queries/mutations, auth, async HTTP via vim.system()
  view.lua       — floating window rendering for results
  solution.lua   — fetch template, create buffer, local file save/load
```

## Config

```lua
require("unemployment").setup({
  session_cookie = "",            -- required
  csrf_token = "",                -- required
  solutions_dir = "~/leetcode",   -- required
  language = "python3",           -- default language for new files
})
```

## Dependencies

**Zero.** Uses `vim.system()` (Neovim 0.10+) for async HTTP. No plenary, no curl dependency.

## Data Flow

1. **Open** → `api.graphql("questionData", { slug })` → parse template → `vim.api.nvim_create_buf()` → save to disk
2. **Test** → `api.graphql("runCode", { slug, code, lang })` → receive submissionId → poll `checkSubmission` every 1s → display float
3. **Submit** → same flow but `submitCode` mutation → poll → display float with pass/fail + runtime + memory + test case details

## Async Behavior

- All API calls via `vim.system()` callbacks
- Editor never blocks during API calls or polling
- Status notification on start, results pop up when ready

## Auth

LEETCODE_SESSION cookie + csrfToken in headers. Plugin does **not** log in; user provides cookie from browser devtools.
