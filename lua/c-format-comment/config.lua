---@class Comment_Delimiter_Options : table
---@field first_line_start string Comment start delimiter for the first line of the comment block.
---@field first_line_end string Comment end delimiter for the first line of the comment block.
---@field line_start string Comment start delimiter for all lines excluding the first/last lines of the comment block.
---@field line_end string Comment end delimiter for all lines excluding the first/last lines of the comment block.
---@field last_line_start string Comment start delimiter for the last line of the comment block.
---@field last_line_end string Comment end delimiter for the last line of the comment block.

--- Default options
---@class C_Format_Comment_Options : table
---@field max_col integer Maximum column for the right most character of end delimieters. Defaults to textwidth for the local buffer if zero. */
---@field box_comment boolean Use box style comments.
---@field delimiter Comment_Delimiter_Options Comment block options.
local defaults = {

  max_col = 80, -- Maximum column for the right most character of end delimiters. Defaults to textwidth for the local buffer if zero. */
  box_comment = false, -- Use box style comments.

  -- Delimiter options for the comment block.
  delimiter = {
    first_line_start = "/*", -- Comment start delimiter for the first line of the comment block.
    first_line_end = "", -- Comment end delimiter for the first line of the comment block.
    line_start = "", -- Comment start delimiter for all lines excluding the first/last lines of the comment block.
    line_end = "", -- Comment end delimiter for all lines excluding the first/last lines of the comment block.
    last_line_start = "", -- Comment start delimiter for the last line of the comment block.
    last_line_end = "*/", -- Comment end delimiter for the last line of the comment block.
  },
}

---@class C_Format_Comment_Config : table
---@field namespace integer Namespace for highlights and virtual text.
---@field opts C_Format_Comment_Options User config options.
local config = {
  namespace = vim.api.nvim_create_namespace("cfc"),
  opts = defaults,
}

if vim.g.cfc and vim.g.cfc.opts then
  config.opts = vim.tbl_deep_extend("force", {}, defaults, vim.g.cfc.opts or {})
end

--- Lets user update default options.
---
--- @param opts table? Optional parameters. Not uksed.
---
function config.setup(opts)
  config.opts = vim.tbl_deep_extend("force", {}, defaults, opts or {})
end

return config
