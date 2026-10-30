local ok, err = xpcall(function()
  local repo = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h:h')
  vim.opt.rtp:prepend(repo .. '/nvim')
  local temp = vim.fn.tempname() .. ' xtool test'
  local project = temp .. '/project with spaces'
  local bin = temp .. '/bin'
  vim.fn.mkdir(project .. '/Sources', 'p')
  vim.fn.mkdir(bin, 'p')
  vim.fn.writefile({}, project .. '/Package.swift')
  local output = temp .. '/output'
  vim.fn.writefile({ '#!/bin/sh', 'pwd > "$XTOOL_TEST_OUTPUT"', 'printf "%s\\n" "$@" >> "$XTOOL_TEST_OUTPUT"' }, bin .. '/xtool')
  vim.fn.setfperm(bin .. '/xtool', 'rwxr-xr-x')
  local old_path = vim.env.PATH
  vim.env.PATH = bin .. ':' .. old_path
  vim.env.XTOOL_TEST_OUTPUT = output
  vim.cmd('edit ' .. vim.fn.fnameescape(project .. '/Sources/file.swift'))
  local xtool = require('xtool')
  xtool.setup()
  vim.cmd('Xtool dev --flag value')
  assert(vim.wait(5000, function() return vim.fn.filereadable(output) == 1 and #vim.fn.readfile(output) == 4 end), 'xtool did not run')
  assert(vim.deep_equal(vim.fn.readfile(output), { vim.uv.fs_realpath(project), 'dev', '--flag', 'value' }), 'argv or cwd incorrect: ' .. vim.inspect(vim.fn.readfile(output)) .. ' expected ' .. project)
  vim.cmd('close!')
  vim.fn.delete(output)
  vim.cmd('Xtool')
  assert(vim.wait(5000, function() return vim.fn.filereadable(output) == 1 and #vim.fn.readfile(output) == 2 end), 'xtool help did not run')
  assert(vim.deep_equal(vim.fn.readfile(output), { vim.uv.fs_realpath(project), '--help' }), 'default argv incorrect')
  vim.cmd('close!')
  local original_termopen = vim.fn.termopen
  vim.fn.termopen = function() error('spawn failed') end
  local original_notify = vim.notify
  local spawn_message
  vim.notify = function(text) spawn_message = text end
  assert(not xtool.run({ 'dev' }), 'failed spawn accepted')
  assert(spawn_message:find('Failed to start xtool:', 1, true), 'spawn error absent')
  vim.fn.termopen = original_termopen
  vim.notify = original_notify
  vim.env.PATH = temp .. '/missing'
  local message
  local notify = vim.notify
  vim.notify = function(text) message = text end
  assert(not xtool.run({ 'dev' }), 'missing executable accepted')
  assert(message == 'xtool executable not found in PATH', 'missing executable error absent')
  vim.notify = notify
  vim.env.PATH = old_path
  vim.fn.delete(temp, 'rf')
  print('PASS: xtool argv, project cwd, default help, failed spawn, missing executable')
end, debug.traceback)
if not ok then print(err); vim.cmd('cquit 1') else vim.cmd('qa!') end
