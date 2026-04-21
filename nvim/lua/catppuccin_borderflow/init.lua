local uv = vim.uv or vim.loop

local M = {}

local ns = vim.api.nvim_create_namespace("catppuccin_cmdline_borderflow")

local defaults = {
    enabled = true,
    -- Run the animation timer continuously, even outside cmdline mode.
    run_idle_timer = false,
    -- Time for one full single-character shift around the border.
    shift_cycle_ms = 180,
    -- Smooth interpolation steps between each single-character shift.
    blend_steps = 9,
    -- Keep timer from going too fast.
    min_tick_ms = 14,
    -- Ensure animated border highlights win over window/plugin default border extmarks.
    highlight_priority = 3000,
    -- Debug logger (writes snapshots/errors to a file for diagnosing window detection).
    debug = false,
    debug_log_file = vim.fn.stdpath("state") .. "/catppuccin_borderflow.log",
    default_flavour = "mocha",
    flavour_getter = function()
        return vim.g.catppuccin_flavour
    end,
    -- These are the guide colors used as gradient nodes.
    guide_keys = {
        "rosewater",
        "flamingo",
        "pink",
        "mauve",
        "red",
        "maroon",
        "peach",
        "yellow",
        "green",
        "teal",
        "sky",
        "sapphire",
        "blue",
        "lavender",
    },
}

local border_styles = {
    none = nil,
    single = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
    double = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" },
    rounded = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    solid = { " ", " ", " ", " ", " ", " ", " ", " " },
    bold = { "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" },
    shadow = { "", "", "", " ", "", "", "", " " },
    curved = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
}

local state = {
    opts = nil,
    timer = nil,
    in_tick = false,
    tick_queued = false,
    phase = 0,
    last_phase_ns = nil,
    windows = {},
    overlay_wins = {},
    hl_cache = {},
    guides = {},
    guide_key = nil,
    gradient_cache = {},
    debug_empty_logged = false,
    winhl_fixed = {},
    cmdline_active = false,
}

local function debug_enabled()
    return state.opts and state.opts.debug
end

local function debug_log(message)
    if not debug_enabled() then
        return
    end
    local line = string.format("[%s] %s", os.date("%Y-%m-%d %H:%M:%S"), tostring(message))
    local file = state.opts.debug_log_file
    if type(file) ~= "string" or file == "" then
        return
    end
    local dir = vim.fn.fnamemodify(file, ":h")
    pcall(vim.fn.mkdir, dir, "p")
    pcall(vim.fn.writefile, { line }, file, "a")
end

local function truncate_text(value, max_len)
    if type(value) ~= "string" then
        return tostring(value)
    end
    if #value <= max_len then
        return value
    end
    return value:sub(1, max_len) .. "..."
end

local function debug_snapshot(tag)
    if not debug_enabled() then
        return
    end
    local mode = "?"
    local ok_mode, current_mode = pcall(vim.api.nvim_get_mode)
    if ok_mode and type(current_mode) == "table" and type(current_mode.mode) == "string" then
        mode = current_mode.mode
    end
    debug_log(string.format("%s mode=%s", tag, mode))
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        if not state.overlay_wins[winid] and vim.api.nvim_win_is_valid(winid) then
            local cfg = vim.api.nvim_win_get_config(winid)
            if cfg.relative and cfg.relative ~= "" then
                local border = cfg.border
                local border_desc = type(border)
                if border_desc == "string" then
                    border_desc = "string:" .. border
                elseif border_desc == "table" then
                    border_desc = "table:" .. tostring(#border)
                end
                local ok_hl, hl = pcall(vim.api.nvim_get_option_value, "winhighlight", { win = winid })
                local winhl = truncate_text((ok_hl and hl) or "", 220)
                local cmdline_like = winhl:find("NoiceCmdlinePopupBorder", 1, true)
                    or winhl:find("NoiceCmdlinePopup", 1, true)
                local probable = false
                local z = tonumber(cfg.zindex) or 0
                local width = tonumber(cfg.width) or vim.api.nvim_win_get_width(winid)
                local height = tonumber(cfg.height) or vim.api.nvim_win_get_height(winid)
                if cfg.focusable == false and z >= 180 and width >= 20 and height <= 8 then
                    probable = true
                end
                debug_log(string.format(
                    "  win=%d rel=%s z=%s foc=%s size=%sx%s border=%s cmdline=%s probable=%s winhl=%s",
                    winid,
                    tostring(cfg.relative),
                    tostring(cfg.zindex),
                    tostring(cfg.focusable),
                    tostring(width),
                    tostring(height),
                    border_desc,
                    tostring(cmdline_like and true or false),
                    tostring(probable),
                    winhl
                ))
            end
        end
    end
end

local function normalize_flavour(flavour)
    if type(flavour) ~= "string" then
        return defaults.default_flavour
    end
    local value = flavour:lower()
    if value == "latte" or value == "frappe" or value == "macchiato" or value == "mocha" then
        return value
    end
    return defaults.default_flavour
end

local function normalize_hex(hex)
    if type(hex) ~= "string" then
        return nil
    end
    local value = hex
    if value:sub(1, 1) == "#" then
        value = value:sub(2)
    end
    if #value == 3 then
        value = value:sub(1, 1) .. value:sub(1, 1)
            .. value:sub(2, 2) .. value:sub(2, 2)
            .. value:sub(3, 3) .. value:sub(3, 3)
    end
    if not value:match("^%x%x%x%x%x%x$") then
        return nil
    end
    return "#" .. value:lower()
end

local function hex_to_rgb(hex)
    local value = normalize_hex(hex)
    if not value then
        return nil
    end
    value = value:sub(2)
    return tonumber(value:sub(1, 2), 16), tonumber(value:sub(3, 4), 16), tonumber(value:sub(5, 6), 16)
end

local function rgb_to_hex(r, g, b)
    return string.format("#%02x%02x%02x", math.max(0, math.min(255, r)), math.max(0, math.min(255, g)),
        math.max(0, math.min(255, b)))
end

local function rgb_to_hsv(r, g, b)
    local rf, gf, bf = r / 255, g / 255, b / 255
    local maxv = math.max(rf, gf, bf)
    local minv = math.min(rf, gf, bf)
    local delta = maxv - minv
    local h = 0

    if delta ~= 0 then
        if maxv == rf then
            h = 60 * (((gf - bf) / delta) % 6)
        elseif maxv == gf then
            h = 60 * (((bf - rf) / delta) + 2)
        else
            h = 60 * (((rf - gf) / delta) + 4)
        end
    end

    local s = (maxv == 0) and 0 or (delta / maxv)
    return h, s, maxv
end

local function blend_hex(a, b, t)
    local r1, g1, b1 = hex_to_rgb(a)
    local r2, g2, b2 = hex_to_rgb(b)
    if not r1 or not r2 then
        return normalize_hex(a) or "#ffffff"
    end
    local r = math.floor((r1 + (r2 - r1) * t) + 0.5)
    local g = math.floor((g1 + (g2 - g1) * t) + 0.5)
    local bl = math.floor((b1 + (b2 - b1) * t) + 0.5)
    return rgb_to_hex(r, g, bl)
end

local function active_flavour()
    local getter = (state.opts and state.opts.flavour_getter) or defaults.flavour_getter
    local value = nil
    local ok, result = pcall(getter)
    if ok then
        value = result
    end
    if type(value) ~= "string" or value == "" then
        value = (state.opts and state.opts.default_flavour) or defaults.default_flavour
    end
    return normalize_flavour(value)
end

local function get_palette()
    local flavour = active_flavour()
    if state.guide_key == flavour and #state.guides > 0 then
        return state.guides
    end

    local guide_colors = {}
    local ok_palette, palettes = pcall(require, "catppuccin.palettes")
    if ok_palette and type(palettes.get_palette) == "function" then
        local palette = palettes.get_palette(flavour)
        if type(palette) == "table" then
            for _, key in ipairs(state.opts.guide_keys) do
                local c = normalize_hex(palette[key])
                if c then
                    table.insert(guide_colors, c)
                end
            end
        end
    end

    if #guide_colors == 0 then
        local fallback = { "FloatBorder", "Keyword", "Type", "String", "Identifier", "Function" }
        for _, group in ipairs(fallback) do
            local ok_hl, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
            if ok_hl and hl and hl.fg then
                table.insert(guide_colors, string.format("#%06x", hl.fg))
            end
        end
    end

    local seen = {}
    local unique = {}
    for _, c in ipairs(guide_colors) do
        if not seen[c] then
            seen[c] = true
            table.insert(unique, c)
        end
    end

    local with_hue = {}
    for _, c in ipairs(unique) do
        local r, g, b = hex_to_rgb(c)
        if r then
            local h, s, v = rgb_to_hsv(r, g, b)
            table.insert(with_hue, { color = c, hue = h, sat = s, val = v })
        end
    end

    table.sort(with_hue, function(a, b)
        if a.hue == b.hue then
            if a.sat == b.sat then
                return a.val < b.val
            end
            return a.sat < b.sat
        end
        return a.hue < b.hue
    end)

    if #with_hue > 2 then
        local max_gap = -1
        local split_after = 1
        for i = 1, #with_hue do
            local j = (i % #with_hue) + 1
            local a = with_hue[i].hue
            local b = with_hue[j].hue
            local gap = b - a
            if gap < 0 then
                gap = gap + 360
            end
            if gap > max_gap then
                max_gap = gap
                split_after = i
            end
        end

        local rotated = {}
        for i = 1, #with_hue do
            local idx = ((split_after + i - 1) % #with_hue) + 1
            table.insert(rotated, with_hue[idx].color)
        end
        unique = rotated
    else
        unique = {}
        for _, item in ipairs(with_hue) do
            table.insert(unique, item.color)
        end
    end

    if #unique == 0 then
        unique = { "#ffffff" }
    end

    state.guides = unique
    state.guide_key = flavour
    return unique
end

local function hl_group_for(hex)
    local color = normalize_hex(hex) or "#ffffff"
    local name = "CatppuccinCmdlineBorderFlow_" .. color:sub(2):upper()
    if state.hl_cache[name] then
        return name
    end
    vim.api.nvim_set_hl(0, name, {
        fg = color,
        bg = "NONE",
        nocombine = true,
    })
    state.hl_cache[name] = true
    return name
end

local function clamp_tick_ms(value)
    local v = tonumber(value) or defaults.shift_cycle_ms
    if v < 1 then
        v = 1
    end
    return math.floor(v + 0.5)
end

local function tick_interval_ms()
    local raw = state.opts.shift_cycle_ms / math.max(1, state.opts.blend_steps)
    return math.max(state.opts.min_tick_ms, clamp_tick_ms(raw))
end

local function to_int(value)
    if type(value) ~= "number" then
        return nil
    end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function get_winhighlight(winid)
    local ok, value = pcall(vim.api.nvim_get_option_value, "winhighlight", { win = winid })
    if ok and type(value) == "string" then
        return value
    end
    local ok_old, old = pcall(vim.api.nvim_win_get_option, winid, "winhl")
    if ok_old and type(old) == "string" then
        return old
    end
    return ""
end

local function is_cmdline_popup(winid)
    local cfg = vim.api.nvim_win_get_config(winid)
    if not cfg.relative or cfg.relative == "" then
        return false
    end
    local winhl = get_winhighlight(winid)
    if winhl:find("NoiceCmdlinePopupBorder", 1, true) then
        return true
    end
    if winhl:find("NoiceCmdlinePopup", 1, true) then
        return true
    end
    return false
end

local function in_cmdline_mode()
    local ok, mode = pcall(vim.api.nvim_get_mode)
    if not ok or type(mode) ~= "table" or type(mode.mode) ~= "string" then
        return false
    end
    return mode.mode:sub(1, 1) == "c"
end

local function is_probable_cmdline_float(winid)
    local cfg = vim.api.nvim_win_get_config(winid)
    if cfg.relative ~= "editor" then
        return false
    end
    if cfg.focusable ~= false then
        return false
    end
    local z = tonumber(cfg.zindex) or 0
    if z < 180 then
        return false
    end
    local width = tonumber(cfg.width) or vim.api.nvim_win_get_width(winid)
    local height = tonumber(cfg.height) or vim.api.nvim_win_get_height(winid)
    if width < 20 or height > 8 then
        return false
    end
    return true
end

local function window_size(winid, cfg)
    local width = tonumber(cfg and cfg.width) or vim.api.nvim_win_get_width(winid)
    local height = tonumber(cfg and cfg.height) or vim.api.nvim_win_get_height(winid)
    return width, height
end

local function border_chars(border)
    local value = border
    if value == nil then
        return nil
    end

    if type(value) == "string" then
        local lower = value:lower()
        if lower:find(",") then
            value = vim.split(lower, ",", { trimempty = false })
        else
            local mapped = border_styles[lower]
            if not mapped then
                return nil
            end
            local out = {}
            for i = 1, 8 do
                out[i] = mapped[i]
            end
            return out
        end
    end

    if type(value) ~= "table" then
        return nil
    end

    local chars = {}
    for _, part in ipairs(value) do
        if type(part) == "table" then
            table.insert(chars, part[1] or "")
        elseif type(part) == "string" then
            table.insert(chars, part)
        else
            table.insert(chars, "")
        end
    end

    if #chars == 0 then
        return nil
    end

    while #chars < 8 do
        local current = vim.deepcopy(chars)
        for _, c in ipairs(current) do
            table.insert(chars, c)
            if #chars >= 8 then
                break
            end
        end
    end

    if #chars > 8 then
        local out = {}
        for i = 1, 8 do
            out[i] = chars[i]
        end
        chars = out
    end

    local has_visible = false
    for _, c in ipairs(chars) do
        if c ~= "" then
            has_visible = true
            break
        end
    end
    if not has_visible then
        return nil
    end
    return chars
end

local function is_visible_border_char(ch)
    return type(ch) == "string" and ch ~= "" and not ch:match("^%s+$")
end

local function char_at_col(line, col)
    if type(line) ~= "string" or col < 1 then
        return ""
    end
    return vim.fn.strcharpart(line, col - 1, 1)
end

local function char_to_byte_index(line, char_index)
    if type(vim.str_byteindex) == "function" then
        local ok, idx = pcall(vim.str_byteindex, line, char_index)
        if ok and type(idx) == "number" and idx >= 0 then
            return idx
        end
    end
    local ok_fallback, idx_fallback = pcall(vim.fn.byteidx, line, char_index)
    if ok_fallback and type(idx_fallback) == "number" and idx_fallback >= 0 then
        return idx_fallback
    end
    return nil
end

local function char_byte_range(line, col)
    if type(line) ~= "string" or col < 1 then
        return nil, nil
    end
    local byte_start = char_to_byte_index(line, col - 1)
    if type(byte_start) ~= "number" then
        return nil, nil
    end
    local byte_end = char_to_byte_index(line, col)
    if type(byte_end) ~= "number" or byte_end <= byte_start then
        local ch = char_at_col(line, col)
        if ch == "" then
            return byte_start, byte_start
        end
        byte_end = byte_start + #ch
    end
    return byte_start, byte_end
end

local function collect_buffer_border_path(winid)
    local buf = vim.api.nvim_win_get_buf(winid)
    if not vim.api.nvim_buf_is_valid(buf) then
        return nil, buf
    end

    local width = vim.api.nvim_win_get_width(winid)
    local height = vim.api.nvim_win_get_height(winid)
    if width < 2 or height < 2 then
        return nil, buf
    end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, height, false)
    if #lines < height then
        for _ = #lines + 1, height do
            lines[#lines + 1] = ""
        end
    end

    local function cell(row, col)
        local line = lines[row] or ""
        local ch = char_at_col(line, col)
        if not is_visible_border_char(ch) then
            return nil
        end
        local byte_start = char_to_byte_index(line, col - 1)
        local byte_end = char_to_byte_index(line, col)
        if type(byte_start) ~= "number" then
            return nil
        end
        if type(byte_end) ~= "number" or byte_end <= byte_start then
            byte_end = byte_start + #ch
        end
        return {
            row = row,
            col = col,
            ch = ch,
            byte_start = byte_start,
            byte_end = byte_end,
        }
    end

    if not cell(1, 1) or not cell(1, width) or not cell(height, 1) or not cell(height, width) then
        return nil, buf
    end

    local path = {}
    local top_count, right_count, bottom_count, left_count = 0, 0, 0, 0

    for col = 1, width do
        local c = cell(1, col)
        if c then
            path[#path + 1] = c
            top_count = top_count + 1
        end
    end
    for row = 2, height - 1 do
        local c = cell(row, width)
        if c then
            path[#path + 1] = c
            right_count = right_count + 1
        end
    end
    for col = width, 1, -1 do
        local c = cell(height, col)
        if c then
            path[#path + 1] = c
            bottom_count = bottom_count + 1
        end
    end
    for row = height - 1, 2, -1 do
        local c = cell(row, 1)
        if c then
            path[#path + 1] = c
            left_count = left_count + 1
        end
    end

    local perimeter = (2 * width) + (2 * height) - 4
    local min_expected = math.max(8, math.floor(perimeter * 0.5))
    if #path < min_expected then
        return nil, buf
    end
    if top_count < 2 or bottom_count < 2 or (left_count + right_count) < 2 then
        return nil, buf
    end

    return path, buf
end

local function resolve_float_box(winid, cfg)
    if cfg.relative == "editor"
        and type(cfg.row) == "number"
        and type(cfg.col) == "number"
        and type(cfg.width) == "number"
        and type(cfg.height) == "number" then
        local row = to_int(cfg.row)
        local col = to_int(cfg.col)
        if row and col then
            return {
                row = row,
                col = col,
                width = math.max(1, math.floor(cfg.width)),
                height = math.max(1, math.floor(cfg.height)),
            }
        end
    end

    local pos = vim.api.nvim_win_get_position(winid)
    if not pos or #pos < 2 then
        return nil
    end
    return {
        row = pos[1],
        col = pos[2],
        width = vim.api.nvim_win_get_width(winid),
        height = vim.api.nvim_win_get_height(winid),
    }
end

local function limit_colors(colors, max_count)
    if #colors <= max_count then
        return colors
    end
    local out = {}
    local count = #colors
    for i = 1, max_count do
        local idx = math.floor(((i - 1) * count) / max_count) + 1
        out[i] = colors[idx]
    end
    return out
end

local function compute_node_positions(perimeter, count)
    local nodes = {}
    if count <= 0 then
        return nodes
    end

    local prev = 0
    for i = 0, count - 1 do
        local pos = math.floor((i * perimeter) / count) + 1
        if pos <= prev then
            pos = prev + 1
        end
        if pos > perimeter then
            pos = perimeter
        end
        nodes[#nodes + 1] = pos
        prev = pos
    end
    return nodes
end

local function build_gradient(perimeter, colors)
    if perimeter < 1 then
        return { gradient = {}, nodes = {} }
    end

    local palette = limit_colors(colors, perimeter)
    if #palette == 0 then
        palette = { "#ffffff" }
    end

    local node_positions = compute_node_positions(perimeter, #palette)
    local gradient = {}
    for i = 1, #palette do
        local start_pos = node_positions[i]
        local end_pos = (i < #palette) and node_positions[i + 1] or (node_positions[1] + perimeter)
        local segment_len = math.max(1, end_pos - start_pos)
        local from = palette[i]
        local to = palette[(i % #palette) + 1]

        for step = 0, segment_len - 1 do
            local idx = ((start_pos + step - 1) % perimeter) + 1
            local t = step / segment_len
            gradient[idx] = blend_hex(from, to, t)
        end
    end

    for i = 1, perimeter do
        if not gradient[i] then
            gradient[i] = gradient[i - 1] or palette[1]
        end
    end

    return {
        gradient = gradient,
        nodes = node_positions,
    }
end

local function gradient_for_perimeter(perimeter)
    local colors = get_palette()
    local key = tostring(perimeter) .. "|" .. table.concat(colors, ",")
    local cached = state.gradient_cache[key]
    if cached then
        return cached
    end
    local built = build_gradient(perimeter, colors)
    state.gradient_cache = { [key] = built }
    return built
end

local function sample_gradient(gradient, position_float)
    local p = #gradient
    if p == 0 then
        return "#ffffff"
    end
    if p == 1 then
        return gradient[1]
    end
    local x = ((position_float - 1) % p) + 1
    local i1 = math.floor(x)
    if i1 < 1 then
        i1 = 1
    end
    local frac = x - i1
    local i2 = (i1 % p) + 1
    return blend_hex(gradient[i1], gradient[i2], frac)
end

local function create_overlay_buffer()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "catppuccin-cmdline-borderflow"
    vim.b[buf].catppuccin_cmdline_borderflow_overlay = true
    return buf
end

local function create_overlay_window(buf, zindex)
    local win = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        row = 0,
        col = 0,
        width = 1,
        height = 1,
        style = "minimal",
        border = "none",
        focusable = false,
        zindex = zindex,
    })
    state.overlay_wins[win] = true
    vim.api.nvim_set_option_value("number", false, { win = win })
    vim.api.nvim_set_option_value("relativenumber", false, { win = win })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
    vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
    -- Use editor background so the overlay does not render as a darker floating box.
    vim.api.nvim_set_option_value("winhl", "Normal:Normal,NormalNC:Normal,EndOfBuffer:Normal", { win = win })
    return win
end

local function clear_window_state(winid)
    local item = state.windows[winid]
    if not item then
        return
    end
    debug_log(string.format("clear win=%d mode=%s", winid, tostring(item.mode)))
    if item.sides then
        for _, side in pairs(item.sides) do
            if side.win and vim.api.nvim_win_is_valid(side.win) then
                state.overlay_wins[side.win] = nil
                pcall(vim.api.nvim_win_close, side.win, true)
            end
            if side.buf and vim.api.nvim_buf_is_valid(side.buf) then
                pcall(vim.api.nvim_buf_delete, side.buf, { force = true })
            end
        end
    end
    state.winhl_fixed[winid] = nil
    state.windows[winid] = nil
end

local function clear_item_sides(item)
    if not item or not item.sides then
        return
    end
    for _, side in pairs(item.sides) do
        if side.win and vim.api.nvim_win_is_valid(side.win) then
            state.overlay_wins[side.win] = nil
            pcall(vim.api.nvim_win_close, side.win, true)
        end
        if side.buf and vim.api.nvim_buf_is_valid(side.buf) then
            pcall(vim.api.nvim_buf_delete, side.buf, { force = true })
        end
        side.win = nil
        side.buf = nil
    end
end

local function ensure_sides(winid, zindex)
    local item = state.windows[winid]
    if not item then
        return nil
    end
    for name, side in pairs(item.sides) do
        local valid = side.buf
            and vim.api.nvim_buf_is_valid(side.buf)
            and side.win
            and vim.api.nvim_win_is_valid(side.win)
        if not valid then
            side.buf = create_overlay_buffer()
            side.win = create_overlay_window(side.buf, zindex)
        else
            local cfg = vim.api.nvim_win_get_config(side.win)
            cfg.zindex = zindex
            pcall(vim.api.nvim_win_set_config, side.win, cfg)
        end
        item.sides[name] = side
    end
    return item.sides
end

local function set_overlay_config(win, row, col, width, height, zindex, parent_win)
    if not vim.api.nvim_win_is_valid(win) then
        return
    end
    local relative = "editor"
    local config = {
        row = row,
        col = col,
        width = math.max(1, width),
        height = math.max(1, height),
        style = "minimal",
        border = "none",
        focusable = false,
        zindex = zindex,
    }
    if parent_win and vim.api.nvim_win_is_valid(parent_win) then
        relative = "win"
        config.win = parent_win
    end
    config.relative = relative
    pcall(vim.api.nvim_win_set_config, win, config)
end

local function set_buffer_lines(buf, lines)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

local function parse_winhighlight(value)
    local order = {}
    local map = {}
    if type(value) ~= "string" or value == "" then
        return order, map
    end
    for _, part in ipairs(vim.split(value, ",", { trimempty = true })) do
        local key, hl = part:match("^([^:]+):(.*)$")
        if key and key ~= "" then
            if map[key] == nil then
                order[#order + 1] = key
            end
            map[key] = hl or ""
        end
    end
    return order, map
end

local function build_winhighlight(order, map)
    local out = {}
    local used = {}
    for _, key in ipairs(order) do
        if map[key] ~= nil and not used[key] then
            out[#out + 1] = key .. ":" .. map[key]
            used[key] = true
        end
    end
    for key, value in pairs(map) do
        if not used[key] then
            out[#out + 1] = key .. ":" .. value
        end
    end
    return table.concat(out, ",")
end

local function ensure_cmdline_bg(winid)
    local existing = get_winhighlight(winid)
    local order, map = parse_winhighlight(existing)
    map.Normal = "Normal"
    map.NormalNC = "Normal"
    map.EndOfBuffer = "Normal"
    local merged = build_winhighlight(order, map)
    pcall(vim.api.nvim_set_option_value, "winblend", 0, { win = winid })
    pcall(vim.api.nvim_set_option_value, "winhl", merged, { win = winid })
    state.winhl_fixed[winid] = merged
end

local function add_color_extmark(buf, row, col_start, col_end, group)
    local ok, result = pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, col_start, {
        end_col = col_end,
        hl_group = group,
        priority = state.opts.highlight_priority,
    })
    if not ok then
        debug_log(string.format(
            "extmark failed buf=%s row=%s col=%s end=%s group=%s err=%s",
            tostring(buf),
            tostring(row),
            tostring(col_start),
            tostring(col_end),
            tostring(group),
            tostring(result)
        ))
    end
end

local function refresh_candidates()
    local seen = {}
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        seen[winid] = true
        if not state.overlay_wins[winid] then
            local cfg = vim.api.nvim_win_get_config(winid)
            local cmdline_match = is_cmdline_popup(winid) or is_probable_cmdline_float(winid)
            if cfg.relative and cfg.relative ~= "" and cmdline_match then
                ensure_cmdline_bg(winid)
                local chars = border_chars(cfg.border)
                if chars then
                    local item = state.windows[winid]
                    if item and item.mode ~= "overlay" then
                        clear_window_state(winid)
                        item = nil
                    end
                    if not item then
                        state.windows[winid] = {
                            mode = "overlay",
                            chars = chars,
                            sides = {
                                top = {},
                                right = {},
                                bottom = {},
                                left = {},
                            },
                        }
                        debug_log(string.format("candidate overlay win=%d border=%s", winid, type(cfg.border)))
                    else
                        item.mode = "overlay"
                        item.chars = chars
                    end
                else
                    local width, height = window_size(winid, cfg)
                    if width >= 2 and height >= 2 then
                        local buf = vim.api.nvim_win_get_buf(winid)
                        if vim.api.nvim_buf_is_valid(buf) then
                            local item = state.windows[winid]
                            if item and item.mode ~= "buffer" then
                                clear_window_state(winid)
                                item = nil
                            end
                            if not item then
                                state.windows[winid] = {
                                    mode = "buffer",
                                    buf = buf,
                                    sides = {
                                        top = {},
                                        right = {},
                                        bottom = {},
                                        left = {},
                                    },
                                }
                                debug_log(string.format("candidate buffer win=%d buf=%d size=%dx%d", winid, buf, width, height))
                            else
                                item.mode = "buffer"
                                item.buf = buf
                            end
                        elseif state.windows[winid] then
                            clear_window_state(winid)
                        end
                    elseif state.windows[winid] then
                        clear_window_state(winid)
                    end
                end
            elseif state.windows[winid] then
                clear_window_state(winid)
            end
        end
    end

    for winid, _ in pairs(state.windows) do
        if not seen[winid] or not vim.api.nvim_win_is_valid(winid) then
            clear_window_state(winid)
        end
    end
end

local function advance_phase()
    local cycle_ms = math.max(1, tonumber(state.opts and state.opts.shift_cycle_ms) or defaults.shift_cycle_ms)
    if type(uv.hrtime) ~= "function" then
        state.phase = state.phase + (tick_interval_ms() / cycle_ms)
        return
    end

    local now = uv.hrtime()
    if type(now) ~= "number" or now <= 0 then
        return
    end
    if not state.last_phase_ns then
        state.last_phase_ns = now
        return
    end

    local delta_ns = now - state.last_phase_ns
    state.last_phase_ns = now
    if delta_ns <= 0 then
        return
    end

    local delta_ms = delta_ns / 1000000
    state.phase = state.phase + (delta_ms / cycle_ms)
    if state.phase >= 1000000 then
        state.phase = state.phase % 1000000
    end
end

local function draw_cmdline_border(winid, item)
    local cfg = vim.api.nvim_win_get_config(winid)
    if not cfg.relative or cfg.relative == "" then
        clear_window_state(winid)
        return
    end

    local box = resolve_float_box(winid, cfg)
    if not box then
        clear_window_state(winid)
        return
    end

    local border_left = box.col
    local border_top = box.row
    local border_right = box.col + box.width + 1
    local border_bottom = box.row + box.height + 1
    local max_col = vim.o.columns - 1
    local max_row = vim.o.lines - 1
    if border_left < 0 or border_top < 0 or border_right > max_col or border_bottom > max_row then
        clear_window_state(winid)
        return
    end

    local sides = ensure_sides(winid, (cfg.zindex or 50) + 8)
    if not sides then
        return
    end

    local total_top = box.width + 2
    local total_bottom = box.width + 2
    local total_side = box.height
    local zindex = (cfg.zindex or 50) + 8

    set_overlay_config(sides.top.win, box.row, box.col, total_top, 1, zindex)
    set_overlay_config(sides.bottom.win, box.row + box.height + 1, box.col, total_bottom, 1, zindex)
    set_overlay_config(sides.left.win, box.row + 1, box.col, 1, total_side, zindex)
    set_overlay_config(sides.right.win, box.row + 1, box.col + box.width + 1, 1, total_side, zindex)

    local chars = item.chars
    local tl, t, tr = chars[1] or "", chars[2] or "", chars[3] or ""
    local r, br, b, bl, l = chars[4] or "", chars[5] or "", chars[6] or "", chars[7] or "", chars[8] or ""

    local path = {}
    local function push(region, idx, ch)
        if is_visible_border_char(ch) then
            path[#path + 1] = { region = region, idx = idx, ch = ch }
        end
    end

    push("top", 1, tl)
    for i = 2, total_top - 1 do
        push("top", i, t)
    end
    push("top", total_top, tr)

    for i = 1, total_side do
        push("right", i, r)
    end

    push("bottom", total_bottom, br)
    for i = total_bottom - 1, 2, -1 do
        push("bottom", i, b)
    end
    push("bottom", 1, bl)

    for i = total_side, 1, -1 do
        push("left", i, l)
    end

    if #path == 0 then
        clear_window_state(winid)
        return
    end

    local gradient_data = gradient_for_perimeter(#path)
    local gradient = gradient_data.gradient
    local shift = state.phase

    local top_chars, top_colors = {}, {}
    local bottom_chars, bottom_colors = {}, {}
    local left_chars, left_colors = {}, {}
    local right_chars, right_colors = {}, {}

    for i = 1, total_top do
        top_chars[i] = " "
        bottom_chars[i] = " "
    end
    for i = 1, total_side do
        left_chars[i] = " "
        right_chars[i] = " "
    end

    for i, p in ipairs(path) do
        local color = sample_gradient(gradient, i - shift)
        if p.region == "top" then
            top_chars[p.idx] = p.ch
            top_colors[p.idx] = color
        elseif p.region == "right" then
            right_chars[p.idx] = p.ch
            right_colors[p.idx] = color
        elseif p.region == "bottom" then
            bottom_chars[p.idx] = p.ch
            bottom_colors[p.idx] = color
        else
            left_chars[p.idx] = p.ch
            left_colors[p.idx] = color
        end
    end

    local top_line = table.concat(top_chars)
    local bottom_line = table.concat(bottom_chars)
    set_buffer_lines(sides.top.buf, { top_line })
    set_buffer_lines(sides.bottom.buf, { bottom_line })

    local left_lines, right_lines = {}, {}
    for i = 1, total_side do
        left_lines[i] = left_chars[i]
        right_lines[i] = right_chars[i]
    end
    set_buffer_lines(sides.left.buf, left_lines)
    set_buffer_lines(sides.right.buf, right_lines)

    local function apply_line(buf, row, colors, line)
        vim.api.nvim_buf_clear_namespace(buf, ns, row, row + 1)
        for col = 1, #colors do
            local color = colors[col]
            if color then
                local group = hl_group_for(color)
                local byte_start, byte_end = char_byte_range(line, col)
                if type(byte_start) == "number" and type(byte_end) == "number" and byte_end > byte_start then
                    add_color_extmark(buf, row, byte_start, byte_end, group)
                end
            end
        end
    end

    apply_line(sides.top.buf, 0, top_colors, top_line)
    apply_line(sides.bottom.buf, 0, bottom_colors, bottom_line)

    vim.api.nvim_buf_clear_namespace(sides.left.buf, ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(sides.right.buf, ns, 0, -1)
    for i = 1, total_side do
        if left_colors[i] then
            local group = hl_group_for(left_colors[i])
            local line = left_lines[i] or ""
            local byte_start, byte_end = char_byte_range(line, 1)
            if type(byte_start) == "number" and type(byte_end) == "number" and byte_end > byte_start then
                add_color_extmark(sides.left.buf, i - 1, byte_start, byte_end, group)
            end
        end
        if right_colors[i] then
            local group = hl_group_for(right_colors[i])
            local line = right_lines[i] or ""
            local byte_start, byte_end = char_byte_range(line, 1)
            if type(byte_start) == "number" and type(byte_end) == "number" and byte_end > byte_start then
                add_color_extmark(sides.right.buf, i - 1, byte_start, byte_end, group)
            end
        end
    end
end

local function draw_buffer_border(winid, item)
    local cfg = vim.api.nvim_win_get_config(winid)
    if not cfg.relative or cfg.relative == "" then
        clear_window_state(winid)
        return
    end

    local box = resolve_float_box(winid, cfg)
    if not box or box.width < 2 or box.height < 2 then
        clear_window_state(winid)
        return
    end

    local target_buf = vim.api.nvim_win_get_buf(winid)
    if not vim.api.nvim_buf_is_valid(target_buf) then
        clear_window_state(winid)
        return
    end

    vim.api.nvim_buf_clear_namespace(target_buf, ns, 0, -1)
    if item.render_mode ~= "overlay" then
        item.render_mode = "overlay"
        debug_log(string.format("buffer-render overlay win=%d size=%dx%d", winid, box.width, box.height))
    end

    local total_side = math.max(0, box.height - 2)
    local zindex = (cfg.zindex or 50) + 8
    local sides = ensure_sides(winid, zindex)
    if not sides then
        return
    end

    set_overlay_config(sides.top.win, 0, 0, box.width, 1, zindex, winid)
    set_overlay_config(sides.bottom.win, box.height - 1, 0, box.width, 1, zindex, winid)
    set_overlay_config(sides.left.win, 1, 0, 1, math.max(1, total_side), zindex, winid)
    set_overlay_config(sides.right.win, 1, box.width - 1, 1, math.max(1, total_side), zindex, winid)

    local chars = border_styles.rounded
    local tl, t, tr = chars[1], chars[2], chars[3]
    local r, br, b, bl, l = chars[4], chars[5], chars[6], chars[7], chars[8]

    local top_chars, top_colors = {}, {}
    local bottom_chars, bottom_colors = {}, {}
    local left_lines, right_lines = {}, {}
    local left_colors, right_colors = {}, {}

    for col = 1, box.width do
        if col == 1 then
            top_chars[col] = tl
            bottom_chars[col] = bl
        elseif col == box.width then
            top_chars[col] = tr
            bottom_chars[col] = br
        else
            top_chars[col] = t
            bottom_chars[col] = b
        end
    end
    for row = 1, total_side do
        left_lines[row] = l
        right_lines[row] = r
    end

    local path_len = (2 * box.width) + (2 * box.height) - 4
    if path_len < 1 then
        return
    end
    local gradient_data = gradient_for_perimeter(path_len)
    local gradient = gradient_data.gradient
    local shift = state.phase
    local idx = 0

    for col = 1, box.width do
        idx = idx + 1
        top_colors[col] = sample_gradient(gradient, idx - shift)
    end
    for row = 1, total_side do
        idx = idx + 1
        right_colors[row] = sample_gradient(gradient, idx - shift)
    end
    for col = box.width, 1, -1 do
        idx = idx + 1
        bottom_colors[col] = sample_gradient(gradient, idx - shift)
    end
    for row = total_side, 1, -1 do
        idx = idx + 1
        left_colors[row] = sample_gradient(gradient, idx - shift)
    end

    local top_text = table.concat(top_chars)
    local bottom_text = table.concat(bottom_chars)
    set_buffer_lines(sides.top.buf, { top_text })
    set_buffer_lines(sides.bottom.buf, { bottom_text })
    set_buffer_lines(sides.left.buf, left_lines)
    set_buffer_lines(sides.right.buf, right_lines)

    local function apply_line(buf, row, colors, line)
        vim.api.nvim_buf_clear_namespace(buf, ns, row, row + 1)
        for col = 1, #colors do
            local color = colors[col]
            if color then
                local group = hl_group_for(color)
                local byte_start, byte_end = char_byte_range(line, col)
                if type(byte_start) == "number" and type(byte_end) == "number" and byte_end > byte_start then
                    add_color_extmark(buf, row, byte_start, byte_end, group)
                end
            end
        end
    end

    apply_line(sides.top.buf, 0, top_colors, top_text)
    apply_line(sides.bottom.buf, 0, bottom_colors, bottom_text)

    vim.api.nvim_buf_clear_namespace(sides.left.buf, ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(sides.right.buf, ns, 0, -1)
    for row = 1, total_side do
        local left_color = left_colors[row]
        if left_color then
            local group = hl_group_for(left_color)
            local left_line = left_lines[row] or ""
            local left_start, left_end = char_byte_range(left_line, 1)
            if type(left_start) == "number" and type(left_end) == "number" and left_end > left_start then
                add_color_extmark(sides.left.buf, row - 1, left_start, left_end, group)
            end
        end
        local right_color = right_colors[row]
        if right_color then
            local group = hl_group_for(right_color)
            local right_line = right_lines[row] or ""
            local right_start, right_end = char_byte_range(right_line, 1)
            if type(right_start) == "number" and type(right_end) == "number" and right_end > right_start then
                add_color_extmark(sides.right.buf, row - 1, right_start, right_end, group)
            end
        end
    end
end

local function tick()
    if state.in_tick then
        return
    end
    state.in_tick = true

    local ok, err = pcall(function()
        advance_phase()
        refresh_candidates()
        for winid, item in pairs(state.windows) do
            if vim.api.nvim_win_is_valid(winid) then
                if item.mode == "buffer" then
                    draw_buffer_border(winid, item)
                else
                    draw_cmdline_border(winid, item)
                end
            else
                clear_window_state(winid)
            end
        end
    end)

    state.in_tick = false
    if not ok then
        debug_log("tick error: " .. tostring(err))
    else
        if in_cmdline_mode() and next(state.windows) == nil and not state.debug_empty_logged then
            debug_log("no cmdline candidates after tick")
            debug_snapshot("cmdline-empty")
            state.debug_empty_logged = true
        end
    end
end

local function queue_tick()
    if state.tick_queued then
        return
    end
    state.tick_queued = true
    vim.schedule(function()
        state.tick_queued = false
        if state.opts and state.opts.enabled then
            tick()
        end
    end)
end

function M.refresh()
    state.guides = {}
    state.guide_key = nil
    state.gradient_cache = {}
    tick()
    queue_tick()
end

function M.stop()
    if state.timer then
        state.timer:stop()
        state.timer:close()
        state.timer = nil
        debug_log("timer stopped")
    end
    for winid, _ in pairs(state.windows) do
        clear_window_state(winid)
    end
    state.last_phase_ns = nil
    state.cmdline_active = false
    state.windows = {}
    state.overlay_wins = {}
    state.winhl_fixed = {}
end

function M.start()
    if not state.opts or not state.opts.enabled then
        return
    end
    if state.timer then
        return
    end
    if type(uv.hrtime) == "function" then
        state.last_phase_ns = uv.hrtime()
    else
        state.last_phase_ns = nil
    end
    state.timer = uv.new_timer()
    state.timer:start(0, tick_interval_ms(), vim.schedule_wrap(tick))
    debug_log("timer started interval_ms=" .. tostring(tick_interval_ms()))
    queue_tick()
end

function M.enable()
    state.opts.enabled = true
    if state.opts.run_idle_timer then
        M.start()
    else
        M.refresh()
    end
end

function M.disable()
    state.opts.enabled = false
    M.stop()
end

function M.toggle()
    if state.opts.enabled then
        M.disable()
    else
        M.enable()
    end
end

function M.setup(opts)
    state.opts = vim.tbl_deep_extend("force", {}, defaults, opts or {})
    state.phase = 0
    state.last_phase_ns = nil
    state.in_tick = false
    state.tick_queued = false
    state.hl_cache = {}
    state.windows = {}
    state.overlay_wins = {}
    state.winhl_fixed = {}
    state.cmdline_active = false
    state.guides = {}
    state.guide_key = nil
    state.gradient_cache = {}

    local blend = tonumber(state.opts.blend_steps) or defaults.blend_steps
    state.opts.blend_steps = math.max(1, math.floor(blend + 0.5))
    state.opts.shift_cycle_ms = clamp_tick_ms(state.opts.shift_cycle_ms)
    state.opts.min_tick_ms = clamp_tick_ms(state.opts.min_tick_ms)
    local priority = tonumber(state.opts.highlight_priority) or defaults.highlight_priority
    state.opts.highlight_priority = math.max(1, math.floor(priority + 0.5))
    state.opts.run_idle_timer = not not state.opts.run_idle_timer
    state.opts.debug = not not state.opts.debug
    state.debug_empty_logged = false
    if state.opts.debug then
        pcall(vim.fn.writefile, {}, state.opts.debug_log_file)
        debug_log("debug enabled")
        debug_log("setup run_idle_timer=" .. tostring(state.opts.run_idle_timer))
    end

    local augroup = vim.api.nvim_create_augroup("CatppuccinCmdlineBorderFlow", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = augroup,
        callback = function()
            M.refresh()
        end,
    })
    vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineChanged" }, {
        group = augroup,
        callback = function(ev)
            if not (state.opts and state.opts.enabled) then
                return
            end
            state.cmdline_active = true
            local function repaint_burst(delays, schedule_first)
                if schedule_first then
                    vim.schedule(function()
                        if state.opts and state.opts.enabled then
                            tick()
                        end
                    end)
                end
                for _, delay in ipairs(delays) do
                    vim.defer_fn(function()
                        if state.opts and state.opts.enabled then
                            tick()
                        end
                    end, delay)
                end
            end
            if ev.event == "CmdlineEnter" then
                state.debug_empty_logged = false
                debug_snapshot("cmdline-enter")
                M.start()
                tick()
                repaint_burst({ 18, 52, 110, 180 }, false)
                queue_tick()
            else
                -- CmdlineChanged can fire before Noice finishes resizing the popup.
                -- Avoid immediate repaint; it often runs before Noice applies new geometry and causes stale side flicker.
                M.start()
                repaint_burst({ 8, 24, 54 }, false)
            end
        end,
    })
    vim.api.nvim_create_autocmd("CmdlineLeave", {
        group = augroup,
        callback = function()
            state.cmdline_active = false
            debug_snapshot("cmdline-leave")
            if state.opts and state.opts.enabled and not state.opts.run_idle_timer then
                M.stop()
            end
        end,
    })
    vim.api.nvim_create_autocmd({ "ModeChanged", "WinNew", "WinClosed", "VimResized" }, {
        group = augroup,
        callback = function()
            if state.opts and state.opts.enabled then
                if state.opts.run_idle_timer or in_cmdline_mode() then
                    M.start()
                end
                tick()
            end
            queue_tick()
        end,
    })

    vim.api.nvim_create_user_command("CatppuccinCmdlineBorderFlowToggle", function()
        M.toggle()
    end, { desc = "Toggle Catppuccin cmdline border animation" })
    vim.api.nvim_create_user_command("CatppuccinCmdlineBorderFlowDebugEnable", function()
        state.opts.debug = true
        pcall(vim.fn.writefile, {}, state.opts.debug_log_file)
        debug_log("debug enabled via command")
        debug_snapshot("debug-enable")
        vim.notify("Borderflow debug enabled: " .. state.opts.debug_log_file)
    end, { desc = "Enable Catppuccin cmdline borderflow debug logging" })
    vim.api.nvim_create_user_command("CatppuccinCmdlineBorderFlowDebugDisable", function()
        debug_log("debug disabled via command")
        state.opts.debug = false
        vim.notify("Borderflow debug disabled")
    end, { desc = "Disable Catppuccin cmdline borderflow debug logging" })
    vim.api.nvim_create_user_command("CatppuccinCmdlineBorderFlowDebugSnapshot", function()
        debug_snapshot("manual-snapshot")
        vim.notify("Borderflow snapshot written: " .. state.opts.debug_log_file)
    end, { desc = "Write a borderflow debug snapshot" })

    if state.opts.enabled then
        if state.opts.run_idle_timer then
            M.start()
        else
            debug_log("idle timer disabled; waiting for CmdlineEnter")
        end
    end
end

return M
