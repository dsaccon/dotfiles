-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")


-- Return to the last place when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, "\"")
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- Enable clipboard copy/pasting with other applications
vim.opt.clipboard:append('unnamedplus')

-- Enable selections to be copied to clipboard
vim.o.mouse = ""
