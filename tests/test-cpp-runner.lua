local script = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(script, ":h:h")
vim.opt.rtp:prepend(root .. "/nvim")

local tmp = vim.fn.tempname() .. " cpp runner"
vim.fn.mkdir(tmp, "p")
local source = tmp .. "/hello world.cpp"
local state = tmp .. "/state.json"
local events = {}
local directories = {}
local completed = 0
local output = {}

local function write(path, text)
  local file = assert(io.open(path, "w"))
  file:write(text)
  file:close()
end

local function terminal(argv, options, on_exit)
  table.insert(events, vim.deepcopy(argv))
  table.insert(directories, options.cwd)
  local job = vim.fn.jobstart(argv, {
    cwd = options.cwd,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do table.insert(output, line) end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data) do table.insert(output, line) end
    end,
    on_exit = function(_, code)
      completed = completed + 1
      vim.schedule(function() on_exit(code) end)
    end,
  })
  assert(job > 0, "job did not start")
end

local runner = require("cpp_runner")
runner.setup({
  state_path = state,
  cache_path = tmp .. "/cache",
  terminal = terminal,
  settings = { compiler = "g++", standard = "c++20", flags = { "-Wall" }, program_args = { "two words" } },
})

write(source, [[#include <iostream>
int main(int argc, char**) { std::cout << "ok " << argc << "\n"; }
]])
vim.cmd("edit " .. vim.fn.fnameescape(source))
local opened_source = vim.api.nvim_buf_get_name(0)
assert(runner.run_file())
assert(vim.wait(15000, function() return completed == 2 end, 20), "successful compile/run timed out: " .. table.concat(output, "\\n"))
assert(#events == 2, "successful run must start compile then executable")
assert(events[1][1] == "g++")
assert(vim.tbl_contains(events[1], opened_source), "source path with spaces was split or lost: " .. vim.inspect(events[1]))
assert(events[2][2] == "two words", "program argv was split")
local old_output = events[2][1]

events = {}
completed = 0
write(source, "int main( { return 0; }\n")
vim.cmd("edit!")
assert(runner.run_file())
assert(vim.wait(15000, function() return completed == 1 end, 20), "failed compile timed out")
assert(#events == 1, "failed compile ran a stale executable")
assert(events[1][1] == "g++")
assert(events[1][#events[1]] ~= old_output, "compile outputs must be unique")

assert(vim.fn.filereadable(state) == 0, "test runner should not persist until settings are changed")
write(state, '{"flags":"-Wall"}')
runner.setup({ state_path = state, cache_path = tmp .. "/cache", terminal = terminal })
assert(type(runner._test.settings().flags) == "table", "malformed saved argv was accepted")

local project_root = tmp .. "/cmake project"
vim.fn.mkdir(project_root, "p")
write(project_root .. "/CMakeLists.txt", [[cmake_minimum_required(VERSION 3.20)
project(cpp_runner_test LANGUAGES CXX)
add_executable(hello main.cpp)
]])
write(project_root .. "/main.cpp", [[#include <iostream>
int main() { std::cout << "project ok\n"; }
]])
events, directories, output, completed = {}, {}, {}, 0
runner.setup({
  state_path = state,
  cache_path = tmp .. "/cache",
  terminal = terminal,
  settings = {
    project = {
      kind = "cmake",
      root = project_root,
      build_dir = "build output",
      build_type = "Debug",
      target = "hello",
      run_command = { "build output/hello" },
    },
  },
})
vim.cmd("edit! " .. vim.fn.fnameescape(project_root .. "/main.cpp"))
assert(runner.run_project())
assert(vim.wait(30000, function() return completed == 3 end, 20), "CMake configure/build/run timed out: " .. table.concat(output, "\n"))
assert(#events == 3 and events[1][1] == "cmake" and events[2][1] == "cmake", "CMake pipeline did not configure then build")
assert(events[1][2] == "-S" and events[1][4] == "-B", "CMake configure arguments missing")
assert(events[2][2] == "--build" and events[2][4] == "--target", "CMake target build arguments missing")
assert(events[3][1] == vim.uv.fs_realpath(project_root) .. "/build output/hello", "project executable argv was not rooted safely")
assert(directories[1] == vim.uv.fs_realpath(project_root), "project command did not use configured root")

events, directories, output, completed = {}, {}, {}, 0
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "int main( { return 0; }" })
vim.cmd("write")
assert(vim.uv.fs_utime(project_root .. "/main.cpp", os.time() + 2, os.time() + 2))
assert(runner.run_project())
assert(vim.wait(30000, function() return completed == 2 end, 20), "failed CMake build timed out: " .. table.concat(output, "\n"))
assert(#events == 2, "failed project build ran stale executable")
assert(events[1][1] == "cmake" and events[2][2] == "--build", "failed project pipeline skipped configure or build")

events, directories, output, completed = {}, {}, {}, 0
vim.cmd("edit! " .. vim.fn.fnameescape(source))
local select = vim.ui.select
vim.ui.select = function(_, options, callback)
  assert(options.prompt == "C++ project root: ", "unexpected picker")
  callback(nil)
end
vim.cmd("CppRunProject")
vim.ui.select = select
assert(#events == 0, "cancelled root mismatch started a project job")

vim.fn.delete(tmp, "rf")
print("cpp_runner: ok")
