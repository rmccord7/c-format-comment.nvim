local config = require("c-format-comment.config")

--- @class Comment_Block : table
--- @field protected node TSNode Treesitter node.
--- @field protected valid boolean Indicates if the comment block is a valid c comment.
--- @field protected indent integer Starting column for the start of the comment block. Can use this to determine indentation.
--- @field protected start_row integer Starting line of the comment block.
--- @field protected start_col integer Starting column for the start of the comment block. Can use this to determine indentation.
--- @field protected end_row integer Last line of the comment block. This may change once text is reflow.
--- @field protected end_col integer End column for the last line of the comment block. This may change once text is reflowed.
--- @field protected lines string[] Holds comment block lines. This may change once text is reflowed.

local Comment_Block = {}

--- Creates a new comment.
---
--- @return Comment_Block Comment_Block A new comment.
function Comment_Block.new()
  Comment_Block.__index = Comment_Block

  local new = setmetatable({}, Comment_Block)

  new.valid = false

  -- Make sure treesitter is parsed.
  vim.treesitter.get_parser():parse()

  ---@type TSNode|nil
  new.node = vim.treesitter.get_node()

  if new.node then

    if new.node:type() == "comment" then
      new.valid = true

      new.start_row, new.start_col, new.end_row, new.end_col = new.node:range()

      -- TSNode is zero indexed.
      new.start_row = new.start_row + 1
      new.start_col = new.start_col + 1
      new.end_row = new.end_row + 1
      new.end_col = new.end_col + 1

      -- Indent level is the indentation for the first line of the comment block.
      new.indent = new.start_col - 1

      -- This removes the indentation from the comment block since TS only returns the text.
      new.lines = vim.split(vim.treesitter.get_node_text(new.node, 0), "\n")
    else
      print("Not a TS comment")
    end
  end

  return new
end

--- Removes delimiters from the comment block.
function Comment_Block:_remove_delimiters()
  -- Remove indentation, comment delimiters, and trailing white space from all
  -- lines.
  for index, line in ipairs(self.lines) do
    -- Remove indent and trailing white space.
    line = vim.trim(line)

    -- Need to handle the case where the user previously joined lines from a block style comment block.

    -- Remove all comment prefixs.
    line, _ = string.gsub(line, vim.pesc("/*"), "")

    -- Remove all comment suffixs.
    line, _ = string.gsub(line, vim.pesc("*/"), "")

    -- Remove all trailing space now that delimeters
    -- have been removed
    line = vim.trim(line)

    -- Update the line.
    self.lines[index] = line
  end

  -- Update the lines in the buffer (API zero indexed).
  vim.api.nvim_buf_set_lines(0, self.start_row - 1, self.end_row, false, self.lines)
end

--- Add delimiters to the comment block.
function Comment_Block:_add_delimiters()
  -- Add comment delimeters back to the lines.
  for index, line in ipairs(self.lines) do
    local start_delimiter
    local end_delimiter

    if index == 1 then
      start_delimiter = config.opts.delimiter.first_line_start
      end_delimiter = config.opts.delimiter.first_line_end

      -- If this is the only line, then this is also the last line so we need
      -- to make sure to the terminate the comment block with the mandatory
      -- last line end delimited.
      if index == #self.lines then
        end_delimiter = config.opts.delimiter.last_line_end
      end
    elseif index == #self.lines then
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
      box_padding = config.opts.max_col - self.indent - start_delimiter_padding - 1 - #line
    else
      -- Only add a space if the end delimiter is present for non box style
      -- comments.
      if #end_delimiter > 0 then
        box_padding = 1
      end
    end

    -- Format the line.
    line = string.rep(" ", self.indent) ..
        start_delimiter ..
        string.rep(" ", start_delimiter_padding) .. line .. string.rep(" ", box_padding) .. end_delimiter

    -- Update the line.
    self.lines[index] = line
  end

  -- Update the lines in the buffer (API zero indexed).
  vim.api.nvim_buf_set_lines(0, self.start_row - 1, self.end_row, false, self.lines)
end

--- Reflows the comment block.
function Comment_Block:_reflow_text()
  -- Visually select all lines in the range.
  vim.api.nvim_feedkeys(string.format("%dGV%dG", self.start_row, self.end_row), "x", false)

  local text_width

  if config.opts.max_col ~= 0 then
    -- The maximum length of text needs to account for the current
    -- indent level and length of the delimiter.
    text_width = config.opts.max_col - self.indent - #config.opts.delimiter.first_line_start - 1
  else
    text_width = vim.api.nvim_get_option_value("textwidth", { buf = 0 }) - self.indent -
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
  self.end_row = unpack(vim.api.nvim_buf_get_mark(0, "]"))

  -- Clear the visual selection.
  vim.api.nvim_feedkeys(vim.api.nvim_eval('"\\<ESC>"'), "x", false)

  -- Get the lines from the selection (API zero indexed).
  self.lines = vim.api.nvim_buf_get_lines(0, self.start_row - 1, self.end_row, false)
end

--- Checks if the cursor is located within a c comment block.
function Comment_Block:is_comment_block()
  return self.valid
end

--- Prints information about the comment block.
function Comment_Block:print()
  print("start row: " .. self.start_row)
  print("start col: " .. self.start_col)
  print("end row: " .. self.end_row)
  print("end col: " .. self.end_col)
  print("indent: " .. self.indent)

  print(vim.inspect(self.lines))
end

--- Checks the specified range to determine if it is in range of the comment block.
---
--- @return boolean in_range True if the specified selection is in range of the comment block. Otherwise false is returned.
function Comment_Block:check_range(start_row, start_col, end_row, end_col)
  print("start row: " .. start_row)
  print("start col: " .. start_col)
  print("end row: " .. end_row)
  print("end col: " .. end_col)

  self:print()

  if start_row == self.start_row and end_row == self.end_row then
    return true
  end

  return false
end

--- Checks if the comment block has a mal-formatted comment.
---
--- @return boolean bad True if the comment block is malformatted. False, otherwise.
function Comment_Block:is_bad()
  return false
end

--- Formats the comment block.
function Comment_Block:format()
  -- Remove the delimiters from the comment block.
  self:_remove_delimiters()

  -- Reflow the comment block.
  self:_reflow_text()

  -- Add delimiters back to the reflowed text.
  self:_add_delimiters()
end

return Comment_Block
