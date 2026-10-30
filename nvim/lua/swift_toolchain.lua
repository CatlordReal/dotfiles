local M = {}

-- Command Line Tools cannot build iOS apps. Use an installed Xcode for these
-- Swift processes only, without changing xcode-select or overriding user choice.
function M.environment()
  if vim.fn.has("macunix") ~= 1 or vim.env.DEVELOPER_DIR then return nil end
  local ok, selected = pcall(function()
    return vim.system({ "xcode-select", "-p" }, { text = true }):wait(2000)
  end)
  if not ok or selected.code ~= 0 or vim.trim(selected.stdout or "") ~= "/Library/Developer/CommandLineTools" then
    return nil
  end
  for _, app in ipairs({ "/Applications/Xcode.app", "/Applications/Xcode-beta.app" }) do
    local developer = app .. "/Contents/Developer"
    if vim.fn.executable(developer .. "/usr/bin/xcodebuild") == 1 then
      return { DEVELOPER_DIR = developer }
    end
  end
end

return M
