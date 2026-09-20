local M = {}

M.languages = {
  "lua", "c", "cpp", "c_sharp", "swift", "objc", "json", "xml", "markdown", "markdown_inline",
  "bash", "python", "html", "yaml", "javascript", "typescript", "css",
}

local configured = {}
for _, language in ipairs(M.languages) do
  configured[language] = true
end

function M.start_buffer(buffer)
  if not vim.api.nvim_buf_is_valid(buffer) then return false end
  local filetype = vim.bo[buffer].filetype
  local ok, language = pcall(vim.treesitter.language.get_lang, filetype)
  if not ok or not configured[language] then return false end
  return pcall(vim.treesitter.start, buffer, language)
end

function M.refresh_buffers()
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    M.start_buffer(buffer)
  end
end

function M.setup(treesitter)
  treesitter = treesitter or require("nvim-treesitter")
  treesitter.setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
  local group = vim.api.nvim_create_augroup("dotfiles_treesitter", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "*",
    callback = function(args) M.start_buffer(args.buf) end,
  })
  M.refresh_buffers()
  local task = treesitter.install(M.languages)
  task:await(function(err)
    vim.schedule(function()
      if err then
        vim.notify("Tree-sitter parser install failed: " .. tostring(err), vim.log.levels.WARN)
      else
        M.refresh_buffers()
      end
    end)
  end)
end

return M
