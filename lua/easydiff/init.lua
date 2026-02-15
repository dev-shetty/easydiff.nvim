-- easydiff.nvim - A simple, intuitive git diff plugin for Neovim
-- Main entry point
local M = {}

local config = require("easydiff.config")
local ui = require("easydiff.ui")
local explorer = require("easydiff.explorer")

-- Plugin version
M.version = "0.1.0"

-- Setup function - call this from your init.lua
-- @param opts table|nil User configuration options
function M.setup(opts)
  -- Initialize configuration
  config.setup(opts)

  -- Set up global keymap to open EasyDiff
  local keymaps = config.get("keymaps")
  vim.keymap.set("n", keymaps.open, function()
    M.open()
  end, { desc = "Open EasyDiff" })

  -- Register user command
  vim.api.nvim_create_user_command("EasyDiff", function()
    M.open()
  end, { desc = "Open EasyDiff git diff viewer" })

  vim.api.nvim_create_user_command("EasyDiffClose", function()
    M.close()
  end, { desc = "Close EasyDiff" })
end

-- Open EasyDiff
function M.open()
  local success = ui.open()
  if success then
    local has_files = explorer.render()
    -- Auto-open first file if there are changes
    if has_files then
      explorer.open_first_file()
    end
  end
end

-- Close EasyDiff
function M.close()
  ui.close()
end

-- Toggle EasyDiff
function M.toggle()
  if ui.is_open() then
    M.close()
  else
    M.open()
  end
end

-- Check if EasyDiff is currently open
function M.is_open()
  return ui.is_open()
end

-- Refresh the explorer and diff view
function M.refresh()
  if ui.is_open() then
    explorer.refresh()
  end
end

return M
