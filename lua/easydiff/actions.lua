-- easydiff.nvim actions module
-- Stage/unstage operations for files and hunks
local M = {}

local git = require("easydiff.git")
local ui = require("easydiff.ui")
local diff = require("easydiff.diff")
local explorer = require("easydiff.explorer")
local config = require("easydiff.config")

-- Helper to refresh UI after changes
local function refresh_ui()
  if config.get("auto_refresh") then
    -- Small delay to let git settle
    vim.defer_fn(function()
      explorer.refresh()

      -- Re-render diff if a file is open
      local diff_state = diff.get_state()
      if diff_state.filepath then
        diff.render(diff_state.filepath, diff_state.is_staged)
      end
    end, 50)
  end
end

-- Stage the current file (from diff view)
function M.stage_file()
  local state = ui.get_state()
  local diff_state = diff.get_state()

  if not diff_state.filepath then
    vim.notify("EasyDiff: No file open", vim.log.levels.WARN)
    return
  end

  local success, err = git.stage_file(diff_state.filepath)
  if success then
    vim.notify("EasyDiff: Staged " .. diff_state.filepath, vim.log.levels.INFO)
    refresh_ui()
  else
    vim.notify("EasyDiff: Failed to stage - " .. (err or "unknown error"), vim.log.levels.ERROR)
  end
end

-- Unstage the current file (from diff view)
function M.unstage_file()
  local state = ui.get_state()
  local diff_state = diff.get_state()

  if not diff_state.filepath then
    vim.notify("EasyDiff: No file open", vim.log.levels.WARN)
    return
  end

  local success, err = git.unstage_file(diff_state.filepath)
  if success then
    vim.notify("EasyDiff: Unstaged " .. diff_state.filepath, vim.log.levels.INFO)
    refresh_ui()
  else
    vim.notify("EasyDiff: Failed to unstage - " .. (err or "unknown error"), vim.log.levels.ERROR)
  end
end

-- Stage a file by path (from explorer)
function M.stage_file_by_path(filepath)
  local success, err = git.stage_file(filepath)
  if success then
    vim.notify("EasyDiff: Staged " .. filepath, vim.log.levels.INFO)
    refresh_ui()
  else
    vim.notify("EasyDiff: Failed to stage - " .. (err or "unknown error"), vim.log.levels.ERROR)
  end
end

-- Unstage a file by path (from explorer)
function M.unstage_file_by_path(filepath)
  local success, err = git.unstage_file(filepath)
  if success then
    vim.notify("EasyDiff: Unstaged " .. filepath, vim.log.levels.INFO)
    refresh_ui()
  else
    vim.notify("EasyDiff: Failed to unstage - " .. (err or "unknown error"), vim.log.levels.ERROR)
  end
end

-- Stage the current hunk
function M.stage_hunk()
  local diff_state = diff.get_state()

  if not diff_state.filepath then
    vim.notify("EasyDiff: No file open", vim.log.levels.WARN)
    return
  end

  if diff_state.is_staged then
    vim.notify("EasyDiff: Cannot stage from staged view (already staged)", vim.log.levels.WARN)
    return
  end

  -- Find the hunk at cursor
  local hunk_idx, hunk = diff.get_hunk_at_cursor()

  if not hunk then
    vim.notify("EasyDiff: No hunk at cursor position", vim.log.levels.WARN)
    return
  end

  -- Get hunk lines for patching
  local hunk_lines, header = diff.get_hunk_patch(hunk_idx)

  if not hunk_lines or not header then
    vim.notify("EasyDiff: Could not get hunk data", vim.log.levels.ERROR)
    return
  end

  local success, err = git.stage_hunk(diff_state.filepath, hunk_lines, header)
  if success then
    vim.notify("EasyDiff: Staged hunk", vim.log.levels.INFO)
    refresh_ui()
  else
    vim.notify("EasyDiff: Failed to stage hunk - " .. (err or "unknown error"), vim.log.levels.ERROR)
  end
end

-- Unstage the current hunk
function M.unstage_hunk()
  local diff_state = diff.get_state()

  if not diff_state.filepath then
    vim.notify("EasyDiff: No file open", vim.log.levels.WARN)
    return
  end

  if not diff_state.is_staged then
    vim.notify("EasyDiff: Cannot unstage from unstaged view", vim.log.levels.WARN)
    return
  end

  -- Find the hunk at cursor
  local hunk_idx, hunk = diff.get_hunk_at_cursor()

  if not hunk then
    vim.notify("EasyDiff: No hunk at cursor position", vim.log.levels.WARN)
    return
  end

  -- Get hunk lines for patching
  local hunk_lines, header = diff.get_hunk_patch(hunk_idx)

  if not hunk_lines or not header then
    vim.notify("EasyDiff: Could not get hunk data", vim.log.levels.ERROR)
    return
  end

  local success, err = git.unstage_hunk(diff_state.filepath, hunk_lines, header)
  if success then
    vim.notify("EasyDiff: Unstaged hunk", vim.log.levels.INFO)
    refresh_ui()
  else
    vim.notify("EasyDiff: Failed to unstage hunk - " .. (err or "unknown error"), vim.log.levels.ERROR)
  end
end

-- Navigate to next changed file
function M.next_file()
  local files = explorer.get_all_files()
  if #files == 0 then
    return
  end

  local diff_state = diff.get_state()
  local current_idx = nil

  -- Find current file index
  if diff_state.filepath then
    current_idx = explorer.find_file_index(diff_state.filepath, diff_state.is_staged)
  end

  -- Calculate next index
  local next_idx
  if current_idx then
    next_idx = current_idx + 1
    if next_idx > #files then
      next_idx = 1 -- Wrap around
    end
  else
    next_idx = 1
  end

  -- Open the file
  local file = files[next_idx]
  if file then
    ui.open_file_in_diff(file.path, file.is_staged)
    explorer.move_to_file(next_idx)
  end
end

-- Navigate to previous changed file
function M.prev_file()
  local files = explorer.get_all_files()
  if #files == 0 then
    return
  end

  local diff_state = diff.get_state()
  local current_idx = nil

  -- Find current file index
  if diff_state.filepath then
    current_idx = explorer.find_file_index(diff_state.filepath, diff_state.is_staged)
  end

  -- Calculate previous index
  local prev_idx
  if current_idx then
    prev_idx = current_idx - 1
    if prev_idx < 1 then
      prev_idx = #files -- Wrap around
    end
  else
    prev_idx = #files
  end

  -- Open the file
  local file = files[prev_idx]
  if file then
    ui.open_file_in_diff(file.path, file.is_staged)
    explorer.move_to_file(prev_idx)
  end
end

return M
