local ok, err = xpcall(function()
  local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
  vim.opt.rtp:prepend(repo .. "/nvim")
  local root = vim.fn.tempname() .. ' terminal test'
  vim.fn.mkdir(root, 'p')
  local source = root .. "/hello '$;.cpp"
  vim.fn.writefile({'#include <iostream>', 'int main() { std::cout << "terminal runner passed" << std::endl; }'}, source)
  local runner = require('cpp_runner').setup({ state_path = root .. '/state.json', cache_path = root .. '/cache' })
  vim.cmd('edit ' .. vim.fn.fnameescape(source))
  assert(runner.run_file())
  assert(vim.wait(20000, function()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[b].buftype == 'terminal' and table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), '\n'):find('terminal runner passed', 1, true) then return true end
    end
    return false
  end), 'default terminal compile/run output missing')
  assert(#vim.api.nvim_list_wins() == 2, 'successful compile split should close')
  vim.fn.delete(root, 'rf')
  print('PASS: actual terminal compile/run, metacharacter source path, split cleanup')
end, debug.traceback)
if not ok then print(err); vim.cmd('cquit 1') else vim.cmd('qa!') end
