local c_format_comment = require("c-format-comment")

vim.api.nvim_create_user_command("CFCComment", c_format_comment.format_all, {})
vim.api.nvim_create_user_command("CFCAllComments", c_format_comment.format, {})
vim.api.nvim_create_user_command("CFCFindNextBadComment", c_format_comment.format, {})
