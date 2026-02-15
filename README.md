# easydiff.nvim

A simple, intuitive git diff plugin for Neovim.

<div align="center">
  
https://github.com/user-attachments/assets/9d12b36c-2a54-44e8-9ab8-ef07405dc503

</div>


## Why?

I needed a better way to review AI-generated code. I tried several git plugins:

- **neogit** - Didnt like the UX, struggled to navigate, no inline diffs
- **lazygit** - Felt it was too complex, inline diffs had no syntax highlighting
- **gitsigns** - Close, but staging files was cumbersome (manual navigation + multi-key hotkeys)

I wanted something like VSCode's diff view - simple, inline diffs with syntax highlighting, easy staging.

So I built this, with the help of Claude Opus 4.5, I will be improving it as I face problems.

## Features

- Split view: file explorer on left, diff on right
- Inline diffs with syntax highlighting (VSCode-style)
- Stage/unstage individual hunks or entire files
- Auto-opens first changed file
- Highlights disappear after staging (visual feedback)

## Installation

### lazy.nvim

```lua
{
  "deveeshshetty/easydiff.nvim",
  config = function()
    require("easydiff").setup()
  end,
}
```

## Usage

| Key | Action |
|-----|--------|
| `<leader>ge` | Open EasyDiff |
| `<leader>s` | Stage hunk (diff) / file (explorer) |
| `<leader>S` | Stage entire file |
| `<leader>u` | Unstage hunk (diff) / file (explorer) |
| `<leader>U` | Unstage entire file |
| `<Tab>` | Next file |
| `<S-Tab>` | Previous file |
| `<C-h>` | Focus explorer |
| `<C-l>` | Focus diff |
| `q` | Close |

## Configuration

All keymaps are configurable:

```lua
require("easydiff").setup({
  explorer_width = 35,
  keymaps = {
    open = "<leader>ge",
    stage = "<leader>s",
    stage_file = "<leader>S",
    unstage = "<leader>u",
    unstage_file = "<leader>U",
    next_file = "<Tab>",
    prev_file = "<S-Tab>",
    close = "q",
    focus_explorer = "<C-h>",
    focus_diff = "<C-l>",
  },
})
```

## License

MIT
