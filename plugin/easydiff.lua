-- easydiff.nvim plugin loader
-- This file is auto-loaded by Neovim when the plugin is installed

-- Prevent double loading
if vim.g.loaded_easydiff then
  return
end
vim.g.loaded_easydiff = true

-- Check Neovim version (need 0.8+ for extmarks with virt_lines)
if vim.fn.has("nvim-0.8") ~= 1 then
  vim.notify("EasyDiff requires Neovim 0.8 or higher", vim.log.levels.ERROR)
  return
end

-- Register commands that work before setup() is called
-- These will prompt user to call setup() if not done
vim.api.nvim_create_user_command("EasyDiff", function()
  local ok, easydiff = pcall(require, "easydiff")
  if ok then
    if vim.tbl_isempty(require("easydiff.config").options) then
      -- Auto-setup with defaults if user hasn't called setup
      easydiff.setup({})
    end
    easydiff.open()
  else
    vim.notify("EasyDiff: Failed to load plugin", vim.log.levels.ERROR)
  end
end, { desc = "Open EasyDiff git diff viewer" })

vim.api.nvim_create_user_command("EasyDiffClose", function()
  local ok, easydiff = pcall(require, "easydiff")
  if ok then
    easydiff.close()
  end
end, { desc = "Close EasyDiff" })

vim.api.nvim_create_user_command("EasyDiffToggle", function()
  local ok, easydiff = pcall(require, "easydiff")
  if ok then
    if vim.tbl_isempty(require("easydiff.config").options) then
      easydiff.setup({})
    end
    easydiff.toggle()
  end
end, { desc = "Toggle EasyDiff" })

vim.api.nvim_create_user_command("EasyDiffRefresh", function()
  local ok, easydiff = pcall(require, "easydiff")
  if ok then
    easydiff.refresh()
  end
end, { desc = "Refresh EasyDiff" })
