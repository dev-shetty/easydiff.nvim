-- easydiff.nvim UI module
-- Handles window and buffer management
local M = {}

local config = require("easydiff.config")

-- State tracking
M.state = {
  tab_id = nil,
  explorer_win = nil,
  explorer_buf = nil,
  diff_win = nil,
  diff_buf = nil,
  original_tab = nil,
  current_file = nil,
  is_staged_view = false, -- Are we viewing staged or unstaged changes?
}

-- Create a scratch buffer with options
local function create_scratch_buffer(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  return buf
end

-- Check if EasyDiff is currently open
function M.is_open()
  return M.state.tab_id ~= nil and vim.api.nvim_tabpage_is_valid(M.state.tab_id)
end

-- Open EasyDiff in a new tab
function M.open()
  local git = require("easydiff.git")

  -- Check if we're in a git repo
  if not git.is_git_repo() then
    vim.notify("EasyDiff: Not in a git repository", vim.log.levels.ERROR)
    return false
  end

  -- If already open, focus it
  if M.is_open() then
    vim.api.nvim_set_current_tabpage(M.state.tab_id)
    return true
  end

  -- Save original tab
  M.state.original_tab = vim.api.nvim_get_current_tabpage()

  -- Create new tab
  vim.cmd("tabnew")
  M.state.tab_id = vim.api.nvim_get_current_tabpage()

  -- The current window will become the diff view (takes most space)
  M.state.diff_win = vim.api.nvim_get_current_win()

  -- Create an empty diff buffer initially
  M.state.diff_buf = create_scratch_buffer("EasyDiff://Diff")
  vim.api.nvim_win_set_buf(M.state.diff_win, M.state.diff_buf)

  -- Create a LEFT split for the explorer (smaller, fixed width)
  local width = config.get("explorer_width") or 35
  vim.cmd("topleft " .. width .. "vsplit")
  M.state.explorer_win = vim.api.nvim_get_current_win()

  -- Create explorer buffer
  M.state.explorer_buf = create_scratch_buffer("EasyDiff://Explorer")
  vim.api.nvim_win_set_buf(M.state.explorer_win, M.state.explorer_buf)

  -- Set options for explorer window
  vim.wo[M.state.explorer_win].number = false
  vim.wo[M.state.explorer_win].relativenumber = false
  vim.wo[M.state.explorer_win].signcolumn = "no"
  vim.wo[M.state.explorer_win].foldcolumn = "0"
  vim.wo[M.state.explorer_win].wrap = false
  vim.wo[M.state.explorer_win].cursorline = true
  vim.wo[M.state.explorer_win].winfixwidth = true

  -- Focus explorer
  vim.api.nvim_set_current_win(M.state.explorer_win)

  -- Set up keymaps for the tab
  M._setup_tab_keymaps()

  return true
end

-- Close EasyDiff
function M.close()
  if not M.is_open() then
    return
  end

  -- Go back to original tab if it exists
  if M.state.original_tab and vim.api.nvim_tabpage_is_valid(M.state.original_tab) then
    vim.api.nvim_set_current_tabpage(M.state.original_tab)
  end

  -- Close the EasyDiff tab
  if M.state.tab_id and vim.api.nvim_tabpage_is_valid(M.state.tab_id) then
    -- Get all windows in the tab and close them
    local wins = vim.api.nvim_tabpage_list_wins(M.state.tab_id)
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
  end

  -- Reset state
  M.state = {
    tab_id = nil,
    explorer_win = nil,
    explorer_buf = nil,
    diff_win = nil,
    diff_buf = nil,
    original_tab = nil,
    current_file = nil,
    is_staged_view = false,
  }
end

-- Open a file in the diff window
function M.open_file_in_diff(filepath, is_staged)
  if not M.state.diff_win or not vim.api.nvim_win_is_valid(M.state.diff_win) then
    return false
  end

  local git = require("easydiff.git")
  local root = git.get_root()
  if not root then
    return false
  end

  local full_path = root .. "/" .. filepath
  M.state.current_file = filepath
  M.state.is_staged_view = is_staged or false

  -- Check if file exists (it might be deleted)
  local file_exists = vim.fn.filereadable(full_path) == 1

  if file_exists then
    -- Open the actual file
    vim.api.nvim_set_current_win(M.state.diff_win)
    vim.cmd("edit " .. vim.fn.fnameescape(full_path))
    M.state.diff_buf = vim.api.nvim_get_current_buf()

    -- Apply diff overlays
    local diff = require("easydiff.diff")
    diff.render(filepath, is_staged)
  else
    -- File was deleted, show the old content
    local old_content
    if is_staged then
      old_content = git.show_head(filepath)
    else
      old_content = git.show_staged(filepath) or git.show_head(filepath)
    end

    if old_content then
      -- Create a scratch buffer with the old content
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, old_content)
      vim.bo[buf].buftype = "nofile"
      vim.bo[buf].modifiable = false

      -- Try to set filetype based on extension
      local ext = filepath:match("%.([^%.]+)$")
      if ext then
        local ft = vim.filetype.match({ filename = filepath })
        if ft then
          vim.bo[buf].filetype = ft
        end
      end

      vim.api.nvim_win_set_buf(M.state.diff_win, buf)
      M.state.diff_buf = buf

      -- Mark all lines as deleted
      local diff_mod = require("easydiff.diff")
      diff_mod.render_deleted_file(buf, old_content)
    end
  end

  -- Focus diff window
  vim.api.nvim_set_current_win(M.state.diff_win)

  return true
end

-- Focus the explorer window
function M.focus_explorer()
  if M.state.explorer_win and vim.api.nvim_win_is_valid(M.state.explorer_win) then
    vim.api.nvim_set_current_win(M.state.explorer_win)
  end
end

-- Focus the diff window
function M.focus_diff()
  if M.state.diff_win and vim.api.nvim_win_is_valid(M.state.diff_win) then
    vim.api.nvim_set_current_win(M.state.diff_win)
  end
end

-- Get the current state
function M.get_state()
  return M.state
end

-- Set up keymaps for the EasyDiff tab
function M._setup_tab_keymaps()
  local keymaps = config.get("keymaps")
  local actions = require("easydiff.actions")

  -- Close keymap (works in both windows)
  vim.keymap.set("n", keymaps.close, function()
    M.close()
  end, { buffer = M.state.explorer_buf, desc = "Close EasyDiff" })

  -- Navigation keymaps for diff view will be set up when a file is opened
end

-- Update diff window keymaps (called when file is opened)
function M.setup_diff_keymaps(buf)
  local keymaps = config.get("keymaps")
  local actions = require("easydiff.actions")

  local opts = { buffer = buf, desc = "" }

  -- Close
  opts.desc = "Close EasyDiff"
  vim.keymap.set("n", keymaps.close, M.close, opts)

  -- Stage hunk
  opts.desc = "Stage current hunk"
  vim.keymap.set("n", keymaps.stage, actions.stage_hunk, opts)

  -- Stage file
  opts.desc = "Stage entire file"
  vim.keymap.set("n", keymaps.stage_file, actions.stage_file, opts)

  -- Unstage hunk
  opts.desc = "Unstage current hunk"
  vim.keymap.set("n", keymaps.unstage, actions.unstage_hunk, opts)

  -- Unstage file
  opts.desc = "Unstage entire file"
  vim.keymap.set("n", keymaps.unstage_file, actions.unstage_file, opts)

  -- Next file
  opts.desc = "Next changed file"
  vim.keymap.set("n", keymaps.next_file, actions.next_file, opts)

  -- Previous file
  opts.desc = "Previous changed file"
  vim.keymap.set("n", keymaps.prev_file, actions.prev_file, opts)

  -- Window toggle keymaps
  opts.desc = "Focus explorer"
  vim.keymap.set("n", keymaps.focus_explorer, M.focus_explorer, opts)

  opts.desc = "Focus diff view"
  vim.keymap.set("n", keymaps.focus_diff, M.focus_diff, opts)
end

return M
