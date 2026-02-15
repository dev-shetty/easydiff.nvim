-- easydiff.nvim explorer module
-- File explorer panel with staged/unstaged sections
local M = {}

local config = require("easydiff.config")
local git = require("easydiff.git")
local ui = require("easydiff.ui")

-- Explorer state
M.state = {
  files = {},           -- Flat list of all files in display order
  staged = {},          -- Staged files
  unstaged = {},        -- Unstaged files
  cursor_idx = 1,       -- Current cursor position in files list
}

-- Status character to highlight group mapping
local status_highlights = {
  ["?"] = "EasyDiffUntracked",
  ["M"] = "EasyDiffModified",
  ["A"] = "EasyDiffAdded",
  ["D"] = "EasyDiffDeleted",
  ["R"] = "EasyDiffRenamed",
  ["C"] = "EasyDiffModified",
  ["U"] = "EasyDiffModified",
}

-- Render the explorer buffer
function M.render()
  local state = ui.get_state()
  if not state.explorer_buf or not vim.api.nvim_buf_is_valid(state.explorer_buf) then
    return
  end

  -- Get git status
  local status = git.status()
  M.state.staged = status.staged
  M.state.unstaged = status.unstaged

  -- Build lines and file mapping
  local lines = {}
  local highlights = {}
  M.state.files = {}

  -- Header
  table.insert(lines, "")

  -- Staged section
  if #M.state.staged > 0 then
    table.insert(lines, "━━ Staged Changes ━━━━━━━━━━━━")
    table.insert(highlights, { line = #lines, hl = "EasyDiffStaged" })

    for _, file in ipairs(M.state.staged) do
      local display = string.format("  %s  %s", file.status, file.path)
      table.insert(lines, display)
      table.insert(M.state.files, {
        path = file.path,
        raw_path = file.raw_path,
        status = file.status,
        is_staged = true,
        line = #lines,
      })
      table.insert(highlights, {
        line = #lines,
        col_start = 2,
        col_end = 3,
        hl = status_highlights[file.status] or "EasyDiffModified",
      })
    end

    table.insert(lines, "")
  end

  -- Unstaged section
  if #M.state.unstaged > 0 then
    table.insert(lines, "━━ Unstaged Changes ━━━━━━━━━━")
    table.insert(highlights, { line = #lines, hl = "EasyDiffUnstaged" })

    for _, file in ipairs(M.state.unstaged) do
      local display = string.format("  %s  %s", file.status, file.path)
      table.insert(lines, display)
      table.insert(M.state.files, {
        path = file.path,
        raw_path = file.raw_path,
        status = file.status,
        is_staged = false,
        line = #lines,
      })
      table.insert(highlights, {
        line = #lines,
        col_start = 2,
        col_end = 3,
        hl = status_highlights[file.status] or "EasyDiffModified",
      })
    end
  end

  -- Empty state
  if #M.state.staged == 0 and #M.state.unstaged == 0 then
    table.insert(lines, "")
    table.insert(lines, "  No changes")
    table.insert(lines, "")
    table.insert(lines, "  Working tree clean")
  end

  -- Set buffer content
  vim.bo[state.explorer_buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.explorer_buf, 0, -1, false, lines)
  vim.bo[state.explorer_buf].modifiable = false

  -- Apply highlights
  local ns = vim.api.nvim_create_namespace("easydiff_explorer")
  vim.api.nvim_buf_clear_namespace(state.explorer_buf, ns, 0, -1)

  for _, hl in ipairs(highlights) do
    if hl.col_start then
      vim.api.nvim_buf_add_highlight(
        state.explorer_buf, ns, hl.hl,
        hl.line - 1, hl.col_start, hl.col_end + 1
      )
    else
      vim.api.nvim_buf_add_highlight(
        state.explorer_buf, ns, hl.hl,
        hl.line - 1, 0, -1
      )
    end
  end

  -- Set up keymaps
  M._setup_keymaps()

  -- Position cursor on first file if available
  if #M.state.files > 0 then
    local first_file_line = M.state.files[1].line
    vim.api.nvim_win_set_cursor(state.explorer_win, { first_file_line, 0 })
  end
end

-- Get file at current cursor position
function M.get_file_at_cursor()
  local state = ui.get_state()
  if not state.explorer_win or not vim.api.nvim_win_is_valid(state.explorer_win) then
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(state.explorer_win)
  local line = cursor[1]

  for _, file in ipairs(M.state.files) do
    if file.line == line then
      return file
    end
  end

  return nil
end

-- Get all files (for navigation)
function M.get_all_files()
  return M.state.files
end

-- Find file index by path
function M.find_file_index(path, is_staged)
  for i, file in ipairs(M.state.files) do
    if file.path == path and file.is_staged == is_staged then
      return i
    end
  end
  return nil
end

-- Move cursor to a specific file
function M.move_to_file(index)
  if index < 1 or index > #M.state.files then
    return false
  end

  local file = M.state.files[index]
  local state = ui.get_state()

  if state.explorer_win and vim.api.nvim_win_is_valid(state.explorer_win) then
    vim.api.nvim_win_set_cursor(state.explorer_win, { file.line, 0 })
  end

  return true
end

-- Open file under cursor in diff view
function M.open_selected()
  local file = M.get_file_at_cursor()
  if not file then
    return
  end

  ui.open_file_in_diff(file.path, file.is_staged)
end

-- Refresh explorer
function M.refresh()
  M.render()
end

-- Set up explorer keymaps
function M._setup_keymaps()
  local state = ui.get_state()
  if not state.explorer_buf or not vim.api.nvim_buf_is_valid(state.explorer_buf) then
    return
  end

  local keymaps = config.get("keymaps")
  local actions = require("easydiff.actions")

  local opts = { buffer = state.explorer_buf, nowait = true }

  -- Enter to open file
  vim.keymap.set("n", keymaps.select, M.open_selected, vim.tbl_extend("force", opts, { desc = "Open file in diff view" }))

  -- Stage file
  vim.keymap.set("n", keymaps.stage, function()
    local file = M.get_file_at_cursor()
    if file and not file.is_staged then
      actions.stage_file_by_path(file.path)
    end
  end, vim.tbl_extend("force", opts, { desc = "Stage file" }))

  -- Unstage file
  vim.keymap.set("n", keymaps.unstage, function()
    local file = M.get_file_at_cursor()
    if file and file.is_staged then
      actions.unstage_file_by_path(file.path)
    end
  end, vim.tbl_extend("force", opts, { desc = "Unstage file" }))

  -- Quick navigation
  vim.keymap.set("n", "j", function()
    local cursor = vim.api.nvim_win_get_cursor(state.explorer_win)
    local current_line = cursor[1]

    -- Find next file line
    for _, file in ipairs(M.state.files) do
      if file.line > current_line then
        vim.api.nvim_win_set_cursor(state.explorer_win, { file.line, 0 })
        return
      end
    end
  end, vim.tbl_extend("force", opts, { desc = "Next file" }))

  vim.keymap.set("n", "k", function()
    local cursor = vim.api.nvim_win_get_cursor(state.explorer_win)
    local current_line = cursor[1]

    -- Find previous file line
    for i = #M.state.files, 1, -1 do
      local file = M.state.files[i]
      if file.line < current_line then
        vim.api.nvim_win_set_cursor(state.explorer_win, { file.line, 0 })
        return
      end
    end
  end, vim.tbl_extend("force", opts, { desc = "Previous file" }))

  -- Tab to focus diff window
  vim.keymap.set("n", "<Tab>", function()
    ui.focus_diff()
  end, vim.tbl_extend("force", opts, { desc = "Focus diff view" }))
end

return M
