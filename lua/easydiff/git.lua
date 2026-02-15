-- easydiff.nvim git module
-- Handles all git operations
local M = {}

-- Get the git root directory
function M.get_root()
  local result = vim.fn.systemlist("git rev-parse --show-toplevel")
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result[1]
end

-- Check if we're in a git repository
function M.is_git_repo()
  return M.get_root() ~= nil
end

-- Parse git status --porcelain=v1 output
-- Returns table with staged and unstaged files
function M.status()
  local root = M.get_root()
  if not root then
    return { staged = {}, unstaged = {} }
  end

  local result = vim.fn.systemlist("git status --porcelain=v1")
  if vim.v.shell_error ~= 0 then
    return { staged = {}, unstaged = {} }
  end

  local staged = {}
  local unstaged = {}

  for _, line in ipairs(result) do
    if #line >= 3 then
      local index_status = line:sub(1, 1)
      local worktree_status = line:sub(2, 2)
      local filepath = line:sub(4)

      -- Handle renamed files (R  old -> new)
      local display_path = filepath
      if filepath:match(" %-> ") then
        local _, new_path = filepath:match("(.+) %-> (.+)")
        display_path = new_path or filepath
      end

      -- Index status (staged changes)
      if index_status ~= " " and index_status ~= "?" then
        table.insert(staged, {
          status = index_status,
          path = display_path,
          raw_path = filepath,
        })
      end

      -- Worktree status (unstaged changes)
      if worktree_status ~= " " then
        local status_char = worktree_status
        -- Untracked files show as ?? in porcelain
        if index_status == "?" then
          status_char = "?"
        end
        table.insert(unstaged, {
          status = status_char,
          path = display_path,
          raw_path = filepath,
        })
      end
    end
  end

  return {
    staged = staged,
    unstaged = unstaged,
  }
end

-- Get diff for a file (unstaged changes)
function M.diff(filepath)
  local result = vim.fn.systemlist({ "git", "diff", "--", filepath })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result
end

-- Get diff for a file (staged changes)
function M.diff_staged(filepath)
  local result = vim.fn.systemlist({ "git", "diff", "--cached", "--", filepath })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result
end

-- Get the original content of a file from HEAD
function M.show_head(filepath)
  local result = vim.fn.systemlist({ "git", "show", "HEAD:" .. filepath })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result
end

-- Get the staged content of a file
function M.show_staged(filepath)
  local result = vim.fn.systemlist({ "git", "show", ":" .. filepath })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result
end

-- Stage a file
function M.stage_file(filepath)
  local result = vim.fn.system({ "git", "add", "--", filepath })
  return vim.v.shell_error == 0, result
end

-- Unstage a file
function M.unstage_file(filepath)
  local result = vim.fn.system({ "git", "restore", "--staged", "--", filepath })
  return vim.v.shell_error == 0, result
end

-- Stage a hunk using git apply
-- hunk_lines is a table of diff lines that make up the patch
function M.stage_hunk(filepath, hunk_lines, diff_header)
  -- Build the patch
  local patch = {}

  -- Add diff header
  for _, line in ipairs(diff_header) do
    table.insert(patch, line)
  end

  -- Add hunk lines
  for _, line in ipairs(hunk_lines) do
    table.insert(patch, line)
  end

  -- Write patch to temp file and apply
  local patch_content = table.concat(patch, "\n") .. "\n"
  local tmp_file = vim.fn.tempname()
  local f = io.open(tmp_file, "w")
  if not f then
    return false, "Could not create temp file"
  end
  f:write(patch_content)
  f:close()

  local result = vim.fn.system({ "git", "apply", "--cached", tmp_file })
  local success = vim.v.shell_error == 0

  os.remove(tmp_file)
  return success, result
end

-- Unstage a hunk using git apply --reverse
function M.unstage_hunk(filepath, hunk_lines, diff_header)
  -- Build the patch
  local patch = {}

  -- Add diff header
  for _, line in ipairs(diff_header) do
    table.insert(patch, line)
  end

  -- Add hunk lines
  for _, line in ipairs(hunk_lines) do
    table.insert(patch, line)
  end

  -- Write patch to temp file and apply in reverse
  local patch_content = table.concat(patch, "\n") .. "\n"
  local tmp_file = vim.fn.tempname()
  local f = io.open(tmp_file, "w")
  if not f then
    return false, "Could not create temp file"
  end
  f:write(patch_content)
  f:close()

  local result = vim.fn.system({ "git", "apply", "--cached", "--reverse", tmp_file })
  local success = vim.v.shell_error == 0

  os.remove(tmp_file)
  return success, result
end

-- Parse unified diff into hunks
-- Returns table of hunks, each with:
--   start_line: line number in the new file where hunk starts
--   end_line: line number in the new file where hunk ends
--   old_start: line number in old file
--   old_count: number of lines in old file
--   new_start: line number in new file
--   new_count: number of lines in new file
--   lines: the diff lines for this hunk (including @@ header)
--   deleted_lines: lines that were deleted (content only)
--   added_lines: line numbers that were added
function M.parse_diff(diff_lines)
  if not diff_lines or #diff_lines == 0 then
    return { header = {}, hunks = {} }
  end

  local header = {}
  local hunks = {}
  local current_hunk = nil
  local in_header = true

  for _, line in ipairs(diff_lines) do
    -- Check for hunk header
    local old_start, old_count, new_start, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")

    if old_start then
      in_header = false
      -- Save previous hunk if exists
      if current_hunk then
        table.insert(hunks, current_hunk)
      end

      -- Start new hunk
      old_count = old_count ~= "" and tonumber(old_count) or 1
      new_count = new_count ~= "" and tonumber(new_count) or 1

      current_hunk = {
        old_start = tonumber(old_start),
        old_count = old_count,
        new_start = tonumber(new_start),
        new_count = new_count,
        start_line = tonumber(new_start),
        end_line = tonumber(new_start) + new_count - 1,
        lines = { line },
        deleted_lines = {},
        added_line_numbers = {},
      }
    elseif in_header then
      table.insert(header, line)
    elseif current_hunk then
      table.insert(current_hunk.lines, line)

      -- Track deleted and added lines
      if line:sub(1, 1) == "-" then
        table.insert(current_hunk.deleted_lines, {
          content = line:sub(2),
          line = line,
        })
      elseif line:sub(1, 1) == "+" then
        -- Calculate the actual line number in the new file
        -- We need to count context and added lines
        local new_line_num = current_hunk.new_start
        for i, hunk_line in ipairs(current_hunk.lines) do
          if i == #current_hunk.lines then break end
          local first_char = hunk_line:sub(1, 1)
          if first_char == " " or first_char == "+" then
            new_line_num = new_line_num + 1
          end
        end
        table.insert(current_hunk.added_line_numbers, new_line_num - 1)
      end
    end
  end

  -- Don't forget the last hunk
  if current_hunk then
    table.insert(hunks, current_hunk)
  end

  return {
    header = header,
    hunks = hunks,
  }
end

-- Find which hunk a line number belongs to
function M.find_hunk_at_line(hunks, line_num)
  for i, hunk in ipairs(hunks) do
    if line_num >= hunk.start_line and line_num <= hunk.end_line then
      return i, hunk
    end
  end
  return nil, nil
end

return M
