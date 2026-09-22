local M = {}

local text_filetypes = { markdown = true, text = true, txt = true }

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Writing" })
end

local function british_spelllang()
  return "en_gb"
end

function M.enable_spell(buffer)
  buffer = buffer or vim.api.nvim_get_current_buf()
  local language = british_spelllang()
  vim.bo[buffer].spelllang = language
  local applied = false
  for _, window in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(window) == buffer then
      vim.wo[window].spell = true
      applied = true
    end
  end
  if not applied then
    vim.api.nvim_buf_call(buffer, function()
      vim.wo.spell = true
    end)
  end
end

local function count(lines)
  local text = table.concat(lines, "\n")
  local words = #vim.fn.split(text, [[\_s\+]])
  local paragraphs = 0
  local in_paragraph = false
  for _, line in ipairs(lines) do
    if line:match("%S") then
      if not in_paragraph then paragraphs = paragraphs + 1 end
      in_paragraph = true
    else
      in_paragraph = false
    end
  end
  return {
    characters = vim.fn.strchars(text),
    words = words,
    paragraphs = paragraphs,
    lines = #lines,
  }
end

function M.count_range(first, last)
  return count(vim.api.nvim_buf_get_lines(0, first - 1, last, false))
end

function M.count_command(command)
  local first, last = 1, vim.api.nvim_buf_line_count(0)
  if command.range > 0 then
    first, last = command.line1, command.line2
  end
  local values = M.count_range(first, last)
  local scope = command.range > 0 and "Selected lines" or "Buffer"
  local choices = {
    { label = "Characters", value = values.characters },
    { label = "Words", value = values.words },
    { label = "Paragraphs", value = values.paragraphs },
    { label = "Lines", value = values.lines },
  }
  vim.ui.select(choices, {
    prompt = scope .. " count",
    format_item = function(item) return item.label .. ": " .. item.value end,
  }, function(choice)
    if choice then notify(choice.label .. ": " .. choice.value) end
  end)
end

function M.setup(options)
  options = options or {}
  local group = vim.api.nvim_create_augroup("dotfiles_writing_tools", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = vim.tbl_keys(text_filetypes),
    callback = function(args) M.enable_spell(args.buf) end,
  })
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if text_filetypes[vim.bo[buffer].filetype] then
      M.enable_spell(buffer)
    end
  end
  vim.api.nvim_create_user_command("WritingCount", M.count_command, {
    desc = "Show writing counts",
    range = true,
  })
  if options.keymaps ~= false then
    vim.keymap.set("n", "<leader>wc", "<cmd>WritingCount<CR>", { desc = "Writing Count" })
    vim.keymap.set("x", "<leader>wc", ":<C-U>'<,'>WritingCount<CR>", { desc = "Writing Count Selection" })
  end
  return M
end

M._test = { british_spelllang = british_spelllang, count = count }

return M
