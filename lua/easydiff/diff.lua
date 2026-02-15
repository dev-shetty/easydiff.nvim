-- easydiff.nvim diff module
-- Diff parsing and inline rendering with extmarks
local M = {}

local git = require("easydiff.git")
local ui = require("easydiff.ui")
local config = require("easydiff.config")

-- Namespace for diff extmarks
local ns = vim.api.nvim_create_namespace("easydiff_diff")

-- Current diff state
M.state = {
  filepath = nil,
  is_staged = false,
  parsed_diff = nil,
  diff_header = nil,
}

-- Clear all diff decorations from a buffer
function M.clear(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
end

-- Render diff for a file
function M.render(filepath, is_staged)
  local state = ui.get_state()
  local buf = state.diff_buf

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  -- Clear previous decorations
  M.clear(buf)

  -- Store state
  M.state.filepath = filepath
  M.state.is_staged = is_staged

  -- Get the diff
  local diff_lines
  if is_staged then
    diff_lines = git.diff_staged(filepath)
  else
    diff_lines = git.diff(filepath)
  end

  if not diff_lines or #diff_lines == 0 then
    -- No diff (possibly untracked file)
    local git_status = git.status()
    local is_untracked = false

    for _, f in ipairs(git_status.unstaged) do
      if f.path == filepath and f.status == "?" then
        is_untracked = true
        break
      end
    end

    if is_untracked then
      -- Highlight entire file as added
      M._highlight_entire_file_as_added(buf)
    end
    return
  end

  -- Parse the diff
  local parsed = git.parse_diff(diff_lines)
  M.state.parsed_diff = parsed
  M.state.diff_header = parsed.header

  -- Render each hunk
  for _, hunk in ipairs(parsed.hunks) do
    M._render_hunk(buf, hunk)
  end

  -- Set up keymaps for the diff buffer
  ui.setup_diff_keymaps(buf)
end

-- Render a single hunk
function M._render_hunk(buf, hunk)
  -- We need to figure out where to place deleted lines as virtual lines
  -- and which lines to highlight as added

  -- Track position in hunk
  local new_line = hunk.new_start
  local deleted_batch = {} -- Batch of deleted lines to show together

  for i, line in ipairs(hunk.lines) do
    if i == 1 then
      -- Skip the @@ header line
      goto continue
    end

    local first_char = line:sub(1, 1)
    local content = line:sub(2)

    if first_char == "-" then
      -- Deleted line - accumulate for virtual lines
      table.insert(deleted_batch, {
        { "- " .. content, "EasyDiffDelete" },
      })
    elseif first_char == "+" then
      -- Added line
      -- First, flush any pending deleted lines as virtual lines ABOVE this line
      if #deleted_batch > 0 then
        M._add_virtual_lines(buf, new_line - 1, deleted_batch)
        deleted_batch = {}
      end

      -- Highlight this line as added
      M._highlight_added_line(buf, new_line)
      new_line = new_line + 1
    elseif first_char == " " then
      -- Context line
      -- Flush any pending deleted lines
      if #deleted_batch > 0 then
        M._add_virtual_lines(buf, new_line - 1, deleted_batch)
        deleted_batch = {}
      end
      new_line = new_line + 1
    end

    ::continue::
  end

  -- Flush any remaining deleted lines at the end of hunk
  if #deleted_batch > 0 then
    M._add_virtual_lines(buf, new_line - 1, deleted_batch)
  end
end

-- Add virtual lines above a line number
function M._add_virtual_lines(buf, after_line, virt_lines)
  -- after_line is 1-indexed, but extmarks are 0-indexed
  local row = after_line

  -- Ensure row is valid
  local line_count = vim.api.nvim_buf_line_count(buf)
  if row < 0 then row = 0 end
  if row > line_count then row = line_count end

  vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
    virt_lines = virt_lines,
    virt_lines_above = true,
  })
end

-- Highlight a line as added
function M._highlight_added_line(buf, line_num)
  -- line_num is 1-indexed, but extmarks are 0-indexed
  local row = line_num - 1

  -- Get the line content for sign
  local line_count = vim.api.nvim_buf_line_count(buf)
  if row < 0 or row >= line_count then
    return
  end

  -- Add line highlight
  vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
    line_hl_group = "EasyDiffAdd",
    sign_text = "+",
    sign_hl_group = "EasyDiffAddText",
  })
end

-- Highlight entire file as added (for untracked files)
function M._highlight_entire_file_as_added(buf)
  local line_count = vim.api.nvim_buf_line_count(buf)

  for i = 0, line_count - 1 do
    vim.api.nvim_buf_set_extmark(buf, ns, i, 0, {
      line_hl_group = "EasyDiffAdd",
      sign_text = "+",
      sign_hl_group = "EasyDiffAddText",
    })
  end
end

-- Render a deleted file (show all content as deleted)
function M.render_deleted_file(buf, old_content)
  local ns_del = vim.api.nvim_create_namespace("easydiff_deleted")

  for i = 0, #old_content - 1 do
    vim.api.nvim_buf_set_extmark(buf, ns_del, i, 0, {
      line_hl_group = "EasyDiffDelete",
      sign_text = "-",
      sign_hl_group = "EasyDiffDeleteText",
    })
  end
end

-- Get hunk at current cursor position
function M.get_hunk_at_cursor()
  local state = ui.get_state()
  if not state.diff_win or not vim.api.nvim_win_is_valid(state.diff_win) then
    return nil, nil
  end

  if not M.state.parsed_diff then
    return nil, nil
  end

  local cursor = vim.api.nvim_win_get_cursor(state.diff_win)
  local line = cursor[1]

  return git.find_hunk_at_line(M.state.parsed_diff.hunks, line)
end

-- Get current diff state
function M.get_state()
  return M.state
end

-- Get the full hunk lines for staging (including header)
function M.get_hunk_patch(hunk_index)
  if not M.state.parsed_diff or not hunk_index then
    return nil, nil
  end

  local hunk = M.state.parsed_diff.hunks[hunk_index]
  if not hunk then
    return nil, nil
  end

  return hunk.lines, M.state.diff_header
end

return M
