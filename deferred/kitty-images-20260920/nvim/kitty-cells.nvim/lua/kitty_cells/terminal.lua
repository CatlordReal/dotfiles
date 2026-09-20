local M = {}
local ffi = require("ffi")
if not pcall(ffi.typeof, "kitty_cells_winsize") then ffi.cdef [[
  typedef struct { unsigned short rows, cols, xpixel, ypixel; } kitty_cells_winsize;
  int ioctl(int fd, unsigned long request, ...);
]] end
ffi.cdef [[ int ttyname_r(int fd, char *buf, size_t size); ]]

local function terminal_fd()
  -- Nvim's TUI child can be detached from its controlling terminal while
  -- retaining inherited tty descriptors. /dev/tty then fails with ENXIO.
  for _, fd in ipairs({ 2, 1, 0 }) do
    if vim.uv.guess_handle(fd) == "tty" then return fd, false end
  end
  local fd = vim.uv.fs_open("/dev/tty", "r+", 0)
  return fd, fd ~= nil
end

-- Reading TIOCGWINSZ does not read stdin or interfere with Neovim's input parser.
function M.cell_size()
  local fd, owned = terminal_fd()
  if not fd then return nil, "No controlling terminal; set cell_size explicitly" end
  local size = ffi.new("kitty_cells_winsize[1]")
  local request = ffi.os == "OSX" and 0x40087468 or 0x5413
  local ok = ffi.C.ioctl(fd, request, size) == 0
  if owned then vim.uv.fs_close(fd) end
  local s = size[0]
  if not ok or s.cols == 0 or s.rows == 0 or s.xpixel == 0 or s.ypixel == 0 then
    return nil, "Terminal did not report pixel dimensions; set cell_size = { width = ..., height = ... }"
  end
  return { width = math.floor(s.xpixel / s.cols), height = math.floor(s.ypixel / s.rows) }
end

function M.write(data)
  local fd, owned = terminal_fd()
  assert(fd, "kitty-cells: no writable terminal descriptor")
  -- Nvim sets its inherited descriptors nonblocking. Open the same tty afresh
  -- so a full PTY queue applies backpressure instead of dropping PNG chunks
  -- with EAGAIN. Never change flags on descriptors owned by Neovim.
  local name = ffi.new("char[1024]")
  local resolved = ffi.C.ttyname_r(fd, name, 1024) == 0
  if owned then vim.uv.fs_close(fd) end
  assert(resolved, "kitty-cells: could not resolve terminal device")
  local tty, err = io.open(ffi.string(name), "wb")
  assert(tty, "kitty-cells: " .. tostring(err))
  local written, write_err = tty:write(data)
  local flushed, flush_err = tty:flush()
  tty:close()
  assert(written and flushed, "kitty-cells: " .. tostring(write_err or flush_err))
end

function M.command(keys, payload)
  return "\27_G" .. keys .. (payload and (";" .. payload) or "") .. "\27\\"
end

function M.upload(id, png, cols, rows, write)
  local encoded = vim.base64.encode(png)
  for offset = 1, #encoded, 4096 do
    local chunk = encoded:sub(offset, offset + 4095)
    local more = offset + 4096 <= #encoded and 1 or 0
    local keys = offset == 1
      and ("a=T,f=100,t=d,U=1,q=2,i=%d,c=%d,r=%d,m=%d"):format(id, cols, rows, more)
      or ("q=2,m=%d"):format(more)
    write(M.command(keys, chunk))
  end
end

function M.delete(id, write)
  write(M.command("a=d,d=I,q=2,i=" .. id))
end

return M
