-- easydiff.nvim configuration module
local M = {}

-- Default configuration
M.defaults = {
  -- Explorer panel width
  explorer_width = 35,

  -- Keymaps (all use <leader> prefix except where noted)
  keymaps = {
    open = "<leader>gg",        -- Open EasyDiff
    stage = "<leader>s",        -- Stage file/hunk
    stage_file = "<leader>S",   -- Stage entire file
    unstage = "<leader>u",      -- Unstage file/hunk
    unstage_file = "<leader>U", -- Unstage entire file
    next_file = "<Tab>",        -- Next changed file (no leader)
    prev_file = "<S-Tab>",      -- Previous changed file (no leader)
    close = "q",                -- Close EasyDiff (no leader)
    select = "<CR>",            -- Open file in diff view (no leader)
  },

  -- Signs for gutter
  signs = {
    add = "+",
    delete = "-",
    change = "~",
  },

  -- Highlight colors (will create highlight groups)
  colors = {
    add_bg = "#2d4a30",
    delete_bg = "#4a2d2d",
    add_fg = "#98c379",
    delete_fg = "#e06c75",
    add_line_bg = "#1e3320",
    delete_line_bg = "#3d1f1f",
  },

  -- Auto-refresh after stage/unstage
  auto_refresh = true,
}

-- Current active configuration
M.options = {}

-- Deep merge two tables
local function deep_merge(base, override)
  local result = vim.deepcopy(base)
  for k, v in pairs(override) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

-- Setup configuration with user overrides
function M.setup(opts)
  M.options = deep_merge(M.defaults, opts or {})
  M._setup_highlights()
end

-- Create highlight groups based on config colors
function M._setup_highlights()
  local colors = M.options.colors

  -- Highlight for added lines
  vim.api.nvim_set_hl(0, "EasyDiffAdd", {
    bg = colors.add_line_bg,
  })

  -- Highlight for deleted lines (virtual lines)
  vim.api.nvim_set_hl(0, "EasyDiffDelete", {
    fg = colors.delete_fg,
    bg = colors.delete_bg,
  })

  -- Highlight for added text specifically
  vim.api.nvim_set_hl(0, "EasyDiffAddText", {
    fg = colors.add_fg,
    bg = colors.add_bg,
  })

  -- Highlight for deleted text specifically
  vim.api.nvim_set_hl(0, "EasyDiffDeleteText", {
    fg = colors.delete_fg,
    bg = colors.delete_bg,
  })

  -- Explorer highlights
  vim.api.nvim_set_hl(0, "EasyDiffStaged", {
    fg = "#98c379",
    bold = true,
  })

  vim.api.nvim_set_hl(0, "EasyDiffUnstaged", {
    fg = "#e5c07b",
    bold = true,
  })

  vim.api.nvim_set_hl(0, "EasyDiffUntracked", {
    fg = "#61afef",
  })

  vim.api.nvim_set_hl(0, "EasyDiffModified", {
    fg = "#e5c07b",
  })

  vim.api.nvim_set_hl(0, "EasyDiffAdded", {
    fg = "#98c379",
  })

  vim.api.nvim_set_hl(0, "EasyDiffDeleted", {
    fg = "#e06c75",
  })

  vim.api.nvim_set_hl(0, "EasyDiffRenamed", {
    fg = "#c678dd",
  })

  vim.api.nvim_set_hl(0, "EasyDiffHeader", {
    fg = "#abb2bf",
    bold = true,
  })
end

-- Get a config value
function M.get(key)
  if key then
    return M.options[key]
  end
  return M.options
end

return M
