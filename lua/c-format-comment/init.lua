local config = require("c-format-comment.config")

-- Lua 5.1 compatibility

-- selene: allow(incorrect_standard_library_use)
if not table.unpack then
  table.unpack = unpack
end

--- @class Comment
--- @field line_start integer Starting line for the comment.
--- @field line_end integer Last line for the comment.
--- @field lines string[] Stored lines from line_start to line_end.

--- @class Selection
--- @field line_start integer Starting line for the visual selection.
--- @field line_end integer Last line for the visual selection.
--- @field lines string[] Stored lines from line_start to line_end.

--- @class C_Format_Comment
local C_Format_Comment = {}

--- Checks if the current line is a comment.
---
--- @param line string Current line.
local function is_comment(line)
  -- Remove all whitespace from beginning and end of string.
  line = vim.trim(line)

  local c_comment_block_start = "/*"
  local c_comment_single_start = "//"

  -- Return true if the line begins with a comment. Otherwise false.
  return line:sub(1, #c_comment_block_start) == c_comment_block_start or
  line:sub(1, #c_comment_single_start) == c_comment_single_start
end

--- Checks if the current line is the start of a comment block.
---
--- @param line string Current line.
local function is_start_of_comment_block(line)
  -- Remove all whitespace from beginning and end of string.
  line = vim.trim(line)

  -- The start delimiter for the first line comment is mandatory.
  local start_delimiter = config.opts.delimiter.first_line_start

  if line:sub(1, #start_delimiter) == start_delimiter then
    -- The end delimiter for the first line comment is optional.
    local end_delimiter = config.opts.delimiter.first_line_end

    if string.len(end_delimiter) > 0 then
      if line:sub(-2, #end_delimiter) == end_delimiter then
        return true
      end
    else
      -- There is no end delimiter for the first comment so just return we
      -- matched the start of the comment block.
      return true
    end
  end

  return false
end

--- Checks if the current line is the end of a comment block.
---
--- @param line string Current line.
local function is_end_of_comment_block(line)
  -- Remove all whitespace from beginning and end of string.
  line = vim.trim(line)

  -- The end delimiter for the last line comment is mandatory.
  local end_delimiter = config.opts.delimiter.last_line_start

  if line:sub(-2, #end_delimiter) == end_delimiter then
    -- The start delimiter for the last line comment is optional.
    local start_delimiter = config.opts.delimiter.last_line_end
    if string.len(start_delimiter) > 0 then
      if line:sub(1, #start_delimiter) == start_delimiter then
        return true
      end
    else
      -- There is no start delimiter for the last comment so just return we
      -- matched the end of the comment block.
      return true
    end
  end

  return false
end

--- Checks if the current line of the current comment is malformatted.
---
--- @param line string Current line.
local function is_bad_comment(line)
  -- Get the end of the current comment line.
  local line_col = string.len(line)

  if line_col > config.opts.max_col then
    return true
  else
    return false
  end
end

--- Backup user options that will be modifed to perform proper text reflow.
---
--- @param options table Text/format options.
local function backup_options(options)
  options.textwidth     = vim.api.nvim_get_option_value("textwidth", { buf = 0 })
  options.smartindent   = vim.api.nvim_get_option_value("smartindent", { buf = 0 })
  options.autoindent    = vim.api.nvim_get_option_value("autoindent", { buf = 0 })
  options.cindent       = vim.api.nvim_get_option_value("cindent", { buf = 0 })
  options.smarttab      = vim.api.nvim_get_option_value("smarttab", { scope = "global" })
  options.indentexpr    = vim.api.nvim_get_option_value("indentexpr", { buf = 0 })
  options.formatexpr    = vim.api.nvim_get_option_value("formatexpr", { buf = 0 })
  options.formatoptions = vim.api.nvim_get_option_value("formatoptions", { buf = 0 })

  -- Set options for reflowing text.
  --   Text width option depends on the current indent level and
  --   whether we are formatting a normal or note comment
  vim.api.nvim_set_option_value("smartindent", false, { buf = 0 })
  vim.api.nvim_set_option_value("autoindent", false, { buf = 0 })
  vim.api.nvim_set_option_value("cindent", false, { buf = 0 })
  vim.api.nvim_set_option_value("smarttab", false, { scope = "global" })
  vim.api.nvim_set_option_value("indentexpr", "", { buf = 0 })
  vim.api.nvim_set_option_value("formatexpr", "", { buf = 0 })
  vim.api.nvim_set_option_value("formatoptions", "tcqj", { buf = 0 })
end

--- Restore user options that will be modifed to perform proper text reflow.
---
--- @param options table Text/format options.
local function restore_options(options)
  vim.api.nvim_set_option_value("textwidth", options.textwidth, { buf = 0 })
  vim.api.nvim_set_option_value("smartindent", options.smartindent, { buf = 0 })
  vim.api.nvim_set_option_value("autoindent", options.autoindent, { buf = 0 })
  vim.api.nvim_set_option_value("cindent", options.cindent, { buf = 0 })
  vim.api.nvim_set_option_value("smarttab", options.smarttab, { scope = "global" })
  vim.api.nvim_set_option_value("indentexpr", options.indentexpr, { buf = 0 })
  vim.api.nvim_set_option_value("formatexpr", options.formatexpr, { buf = 0 })
  vim.api.nvim_set_option_value("formatoptions", options.formatoptions, { buf = 0 })
end

--- Visually selects the next bad comment from the current line. If the current
--- line is a bad comment, then that comment will be visually selected.
function C_Format_Comment.find_next_bad_comment()
  local line_count              = vim.api.nvim_buf_line_count(0)

  --Save the current cursor position.
  local previous_line_number, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local current_line_number     = previous_line_number

  -- If we have not reached eof.
  while current_line_number ~= line_count do
    --Get current line (API zero indexed).
    local line = vim.api.nvim_buf_get_lines(0, current_line_number - 1, current_line_number, false)[1]

    --If the current line is a comment.
    if is_comment(line) then
      --If this is a bad comment.
      if is_bad_comment(line) then
        -- Find the offset of the comment start. This offset is
        -- the actual comment string not the delimiter.
        local line_col = string.find(line, "/*", 1, true) + #"/*"

        -- Update the cursor position at beginning of the comment text.
        vim.api.nvim_win_set_cursor(0, { current_line_number, line_col })

        -- Set starting and end line numbers for visually selecting
        -- the comment block.
        local line_start = current_line_number - 1
        local line_end   = current_line_number + 1

        -- Find the start of the comment block.
        while line_start ~= 0 do
          -- Get the current line.
          line = vim.api.nvim_buf_get_lines(0, line_start - 1, line_start, false)[1]

          -- If this line is not a comment, then the next line
          -- is the start of the comment block.
          if not is_comment(line) then
            line_start = line_start + 1
            break
          end

          line_start = line_start - 1;
        end

        -- Find the end of the comment block.
        while line_end ~= line_count do
          -- Get the current line.
          line = vim.api.nvim_buf_get_lines(0, line_end - 1, line_end, false)[1]

          -- If this line is not a comment, then the previous line
          -- is the end of the comment block.
          if not is_comment(line) then
            line_end = line_end - 1
            break
          end

          line_end = line_end + 1;
        end

        -- Visually select the comment block
        vim.api.nvim_feedkeys(string.format("%dGV%dG", line_start, line_end), "n", false)
        break
      end
    end

    --Get next line.
    current_line_number = current_line_number + 1;
  end
end

--- Formats a comment block.
function C_Format_Comment.format()

  local mode = vim.api.nvim_get_mode()['mode']

  if mode ~= 'n' then
    vim.notify("[CFC] Unsupported mode", vim.log.levels.ERROR)
    return
  end

  -- Backup user text options.
  local options = {}

  backup_options(options)

  --- @type Comment_Block
  local Comment_Block = require("c-format-comment.comment")

  local cb = Comment_Block.new()

  if cb:is_comment_block() then

    -- if mode == 'v' or mode == 'V' then
    --   -- Make sure that the visual selection lines up with what is reported by
    --   -- TS for the comment block.
    --   local start_row, start_col = vim.api.nvim_buf_get_mark(0, "<")
    --   local end_row, end_col = vim.api.nvim_buf_get_mark(0, ">")
    --
    --   -- If the visual selection start is not in order of
    --   -- increasing line order swap them. This may happen if
    --   -- the user explicitly made the visual selection.
    --   if start_row > end_row then
    --     start_row, end_row = end_row, start_row
    --     start_col, end_col = end_col, start_col
    --   end
    --
    --   -- Clear the visual selection.
    --   vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), "x", false)
    --
    --   -- Make sure the visual selection is in range of the comment block.
    --   if not cb:check_range(start_row, start_col, end_row, end_col) then
    --     vim.notify("[CFC] Invalid selection", vim.log.levels.ERROR)
    --     return
    --   end
    -- else
    --   -- Nothing to do for normal mode.
    --   if mode ~= 'n' then
    --     vim.notify("[CFC] Unsupported mode", vim.log.levels.ERROR)
    --     return
    --   end
    -- end

    -- Format the comment. This may add additional lines
    -- to the comment block when the text is reflowed.
    cb:format()

    -- Restore user text options.
    restore_options(options)
  else
    vim.notify("[CFC] Not a comment", vim.log.levels.ERROR)
  end
end

--- Formats all ss1 comments in the selection.
function C_Format_Comment.format_all()
  local options = {}

  -- Backup user options. More efficient to this once
  -- instead of each time we format a commentt.
  backup_options(options)

  --- @type Selection
  local selection = {
    line_start = unpack(vim.api.nvim_buf_get_mark(0, "<")),
    line_end   = unpack(vim.api.nvim_buf_get_mark(0, ">")),
    lines      = {},
  }

  -- If the visual selection start is not in order of
  -- increasing line order swap them. This may happen if
  -- the user explicitly made the visual selection.
  if selection.line_start > selection.line_end then
    selection.line_start, selection.line_end = selection.line_end, selection.line_start
  end

  -- Get the lines from the selection (API zero indexed).
  selection.lines = vim.api.nvim_buf_get_lines(0, selection.line_start - 1, selection.line_end, false)

  -- Clear the visual selection.
  vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), "x", false)

  local line
  local index = 1
  local bad_comment = false

  while index <= #selection.lines do
    -- For new comment block.
    local bad_comment_block = false

    -- Get the current line.
    line = selection.lines[index]

    -- Determine if this line is the start of a comment block.
    if is_start_of_comment_block(line) then
      --- @type Comment
      local comment = {
        line_start = selection.line_start,
        line_end   = selection.line_start,
        lines      = {}, -- Only used when formatting a commente block.
      }

      -- If the current line is a bad comment.
      bad_comment = is_bad_comment(line)

      if bad_comment then
        bad_comment_block = true
      end

      -- If this is not the last line, then we need to find the end of the
      -- comment block.
      if index ~= #selection.lines then
        -- Start with the next line and loop through the remaining lines to
        -- find the last line of the comment block.

        -- selene: allow(incorrect_standard_library_use)
        for index2, line2 in ipairs({ table.unpack(selection.lines, index + 1) }) do
          --TODO: Currently broken for current comment finding without being
          --able to determine if the next line is not a comment if we don't
          --have delimieters between lines.

          -- If the current line is a comment, then we have not found the end
          -- of the comment block.
          if is_comment(line2) then
            -- If the current line is a bad comment, then we need to flag it, but
            -- this not the end of the comment block so we need to continue
            -- looking for the end of the comment block.
            bad_comment = is_bad_comment(line2)

            if bad_comment then
              bad_comment_block = true
            end

            -- Update the end of the comment block.
            comment.line_end = comment.line_end + 1

            -- Since we processed additional lines we need to update the main
            -- loop to skip over lines that we already processed in the inner
            -- loop.
            index = index + index2
          else
            -- Store the current line end so that if additional lines are added
            -- we can determine how many were added. The format_comment() function
            -- will update the line of the comment block if it changes.
            local NewLineCount = comment.line_end

            -- Only format the comment block if we determined that it contains
            -- a line that is a bad comment.
            if bad_comment_block then
              C_Format_Comment.format(comment, options)

              -- Set the number of lines that were added after the comment
              -- block was formatted.
              NewLineCount = comment.line_end - NewLineCount
            end

            -- Since we processed additional lines we need to update the main
            -- loop to skip over lines that we already processed in the inner
            -- loop.
            index = index + index2

            -- Continue processing lines in the visual selection.
            break
          end
        end

        -- Handle case where last line is the end of the comment
        -- block.
        if index == #selection.lines then
          if bad_comment_block then
            C_Format_Comment.format(comment, options)
          end
        else
          -- If there are more lines in the visual selection, then there may
          -- be another comment block that needs to be formatted.

          -- Next comment block should start after the current line
          -- (non-comment) that was just processed and marked the end of
          -- the current comment block.
          selection.line_start = comment.line_end + 2
          selection.line_end   = comment.line_end + 2
        end
      else
        -- The line end for the comment block has already been set to start for
        -- this case.

        -- Only format the comment block if we determined that it is a bad
        -- comment.
        if bad_comment_block then
          C_Format_Comment.format(comment, options)
        end
      end
    else
      -- Keep incrementing the next line as the comment start until we find a
      -- comment block. This may happen if the user visual selection has
      -- additional lines before the start of the first comment block.
      selection.line_start = selection.line_start + 1
      selection.line_end   = selection.line_start + 1
    end

    -- Get the next line in the visual selection.
    index = index + 1
  end

  -- Restore user options.
  restore_options(options)
end

return C_Format_Comment
