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

local comment_start = "/*"

--- @class C_Format_Comment
local C_Format_Comment = {}

--- Checks if the current line is a comment.
---
--- @param line string Current line.
local function is_comment(line)
  -- Remove all whitespace from beginning and end of string.
  line = vim.trim(line)

  -- Return true if the line begins with a comment. Otherwise false.
  return line:sub(1, #comment_start) == comment_start
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

--- Reflows the text.
---
--- @param comment Comment Visual selection that may include a comment block.
--- @param indent integer Current indent level before the comment block.
local function reflow_text(comment, indent)
  -- Visually select all lines in the range.
  vim.api.nvim_feedkeys(string.format("%dGV%dG", comment.line_start, comment.line_end), "x", false)

  local text_width

  if config.opts.max_col ~= 0 then
    -- The maximum length of text needs to account for the current
    -- indent level and length of the delimiter.
    text_width = config.opts.max_col - indent - #config.opts.delimiter.first_line_start - 1
  else
    text_width = vim.api.nvim_get_option_value("textwidth", { buf = 0 }) - indent -
        #config.opts.delimiter.first_line_start - 1
  end

  vim.api.nvim_set_option_value("textwidth", text_width, { buf = 0 })

  -- Reflow the text.
  vim.api.nvim_feedkeys("gq", "x", false)

  -- Visually Select the all lines from the reflow. More lines may have been
  -- added, but we can quickly re-select them.
  vim.api.nvim_feedkeys("'[V']", "x", false)

  -- If additional lines were added, then we need to update the last line of
  -- the section. This will be in ascending order order so we don't need to
  -- swap these.
  comment.line_end = unpack(vim.api.nvim_buf_get_mark(0, "]"))

  -- Clear the visual selection.
  vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), "x", false)

  -- Get the lines from the selection (API zero indexed).
  comment.lines = vim.api.nvim_buf_get_lines(0, comment.line_start - 1, comment.line_end, false)
end

--- Formats the comment.
---
--- @param comment Comment Visual selection that may include a comment block.
local function format_comment(comment)
  -- Save the indent level from the current line.
  local indent        = string.find(comment.lines[1], "%S") - 1
  local indent_string = string.sub(comment.lines[1], 1, indent)

  -- Remove indentation, comment delimiters, and trailing white space from all
  -- lines.
  for index, line in ipairs(comment.lines) do
    -- Remove indent and trailing white space.
    line = vim.trim(line)

    -- If we joined lines to reflow a box style comment, then we want to
    -- remove all the extra delimiters that have been included when the
    -- lines were joined.

    -- Remove all comment prefixs.
    line, _ = string.gsub(line, vim.pesc("/*"), "")

    -- Remove all comment suffixs.
    line, _ = string.gsub(line, vim.pesc("*/"), "")

    -- Remove all trailing space now that delimeters
    -- have been removed
    line = vim.trim(line)

    -- Update the line.
    comment.lines[index] = line
  end

  -- Update the lines in the buffer (API zero indexed).
  vim.api.nvim_buf_set_lines(0, comment.line_start - 1, comment.line_end, false, comment.lines)

  -- Reflow the text block. This function will return the new section line end
  -- if additional lines were added to the section due to the reflowing of the
  -- text.
  reflow_text(comment, indent)

  -- Add comment delimeters back to the lines.
  for index, line in ipairs(comment.lines) do
    local start_delimiter
    local end_delimiter

    if index == 1 then
      start_delimiter = config.opts.delimiter.first_line_start
      end_delimiter = config.opts.delimiter.first_line_end
    elseif index == #comment.lines then
      start_delimiter = config.opts.delimiter.last_line_start
      end_delimiter = config.opts.delimiter.last_line_end
    else
      start_delimiter = config.opts.delimiter.line_start
      end_delimiter = config.opts.delimiter.line_end
    end

    -- Only one space between start delimiter and the comment.
    local start_delimiter_padding = 1

    -- Calculate the padding that will be required if the line does not
    -- have a start delimiter.
    if #start_delimiter == 0 then
      -- Assume delimiters are two characters.
      start_delimiter_padding = start_delimiter_padding + 2
    end

    local box_padding = 0

    -- Calculate the padding until the end of line delimiter for box style
    -- comments.
    if config.opts.box_comment then
      box_padding = config.opts.max_col - indent - start_delimiter_padding - 1 - #line
    else
      -- Only add a space if the end delimiter is present for non box style
      -- comments.
      if #end_delimiter > 0 then
        box_padding = 1
      end
    end

    -- Format the line.
    line = indent_string ..
    start_delimiter .. string.rep(" ", start_delimiter_padding) .. line .. string.rep(" ", box_padding) .. end_delimiter

    -- Update the line.
    comment.lines[index] = line
  end

  -- Update the lines in the buffer (API zero indexed).
  vim.api.nvim_buf_set_lines(0, comment.line_start - 1, comment.line_end, false, comment.lines)
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
        local line_col = string.find(line, comment_start, 1, true) + #comment_start

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

--- Formats a comment.
---
--- @param comment Comment Visual selection that may include a comment block.
--- @param options table Text options that need to be restored after the format.
function C_Format_Comment.format(comment, options)
  comment = comment or {}
  options = options or {}

  local restore

  -- If API called explicitly then we need to backup the current user's
  -- options before we reflow the text. It is more efficient to do this
  -- once if we are going to format multiple comment blocks.
  if next(options) == nil then
    backup_options(options)

    -- Flag that we need to restore user options when
    -- we are done.
    restore = true
  else
    restore = false
  end

  -- If API called explicitly then the visual selection must be a comment
  -- block.
  if next(comment) == nil then
    comment = {
      line_start = unpack(vim.api.nvim_buf_get_mark(0, "<")),
      line_end   = unpack(vim.api.nvim_buf_get_mark(0, ">")),
      lines      = {},
    }

    -- If the visual selection start is not in order of
    -- increasing line order swap them. This may happen if
    -- the user explicitly made the visual selection.
    if comment.line_start > comment.line_end then
      comment.line_start, comment.line_end = comment.line_end, comment.line_start
    end

    -- Clear the visual selection.
    vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), "x", false)
  end

  -- Get the lines for the comment block.
  comment.lines = vim.api.nvim_buf_get_lines(0, comment.line_start - 1, comment.line_end, false)

  -- Process the comment.
  for index, line in ipairs(comment.lines) do
    -- If the current line is a comment.
    if is_comment(line) then
      -- If we have reached the end of the comment block.
      if index == #comment.lines then
        -- Format the comment. This may add additional lines
        -- to the comment block when the text is reflowed.
        format_comment(comment)
      end
    else
      vim.notify("[CFC] Not a comment", vim.log.levels.ERROR)

      -- Found a line in the visual selection that is not
      -- a comment. No formatting will be done..
      break
    end
  end

  -- If this was a command, then we need to restore
  -- the user options.
  if restore then
    restore_options(options)
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

    -- If the current line is a comment, then this is the start of a comment
    -- block.
    if is_comment(line) then
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
