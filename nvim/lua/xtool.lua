local M = {}

function M.run(args)
  if vim.fn.executable('xtool') ~= 1 then
    vim.notify('xtool executable not found in PATH', vim.log.levels.ERROR)
    return false
  end

  local file = vim.api.nvim_buf_get_name(0)
  local root = file ~= '' and vim.fs.root(file, { 'Package.swift', '.git' }) or nil
  local argv = { 'xtool' }
  vim.list_extend(argv, #args > 0 and args or { '--help' })

  vim.cmd('botright split')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  local ok, job = pcall(vim.fn.termopen, argv, {
    cwd = root or vim.fn.getcwd(), env = require('swift_toolchain').environment(),
  })
  if not ok or job <= 0 then
    vim.api.nvim_buf_delete(buf, { force = true })
    vim.notify('Failed to start xtool: ' .. tostring(job), vim.log.levels.ERROR)
    return false
  end
  vim.cmd('startinsert')
  return true
end

function M.setup()
  vim.api.nvim_create_user_command('Xtool', function(opts)
    M.run(opts.fargs)
  end, { nargs = '*' })
end

return M
