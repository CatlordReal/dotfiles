local uv = vim.uv or vim.loop

local M = {}

local ns = vim.api.nvim_create_namespace("catppuccin_borderflow")

local defaults = {
    enabled = true,
    frame_ms = 45,
    phase_step = 0.22,
    repeat_threshold = 120,
    default_flavour = "mocha",
    flavour_getter = function()
        return vim.g.catppuccin_flavour
    end,
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
    phase = 0,
    windows = {},
    overlay_wins = {},
    hl_cache = {},
    guides = {},
    guide_key = nil,
    border_groups = {},
    border_group_base = {},
    augroup = nil,
    in_tick = false,
    tick_queued = false,
}

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
    local r = tonumber(value:sub(1, 2), 16)
    local g = tonumber(value:sub(3, 4), 16)
    local b = tonumber(value:sub(5, 6), 16)
    return r, g, b
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
    local v = maxv
    return h, s, v
end

local function blend_hex(a, b, t)
    local r1, g1, b1 = hex_to_rgb(a)
    local r2, g2, b2 = hex_to_rgb(b)
    if not r1 or not r2 then
        return a
    end
    local r = math.floor((r1 + (r2 - r1) * t) + 0.5)
    local g = math.floor((g1 + (g2 - g1) * t) + 0.5)
    local bl = math.floor((b1 + (b2 - b1) * t) + 0.5)
    return rgb_to_hex(r, g, bl)
end

local function hl_group_for(hex, fill)
    local color = normalize_hex(hex) or "#ffffff"
    local name = "CatppuccinBorderFlow_" .. color:sub(2):upper() .. (fill and "_BG" or "_FG")
    if state.hl_cache[name] then
        return name
    end

    local spec = {
        fg = color,
        bg = fill and color or "NONE",
        nocombine = true,
    }
    vim.api.nvim_set_hl(0, name, spec)
    state.hl_cache[name] = true
    return name
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
    local key = flavour
    if state.guide_key == key and #state.guides > 0 then
        return state.guides
    end

    local guide_colors = {}
    local ok_palette, palettes = pcall(require, "catppuccin.palettes")
    if ok_palette and type(palettes.get_palette) == "function" then
        local palette = palettes.get_palette(flavour)
        if type(palette) == "table" then
            for _, k in ipairs(state.opts.guide_keys) do
                local c = normalize_hex(palette[k])
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

    local dedup = {}
    local unique = {}
    for _, c in ipairs(guide_colors) do
        if not dedup[c] then
            dedup[c] = true
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
            local gap = (b - a)
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

    state.guides = unique
    state.guide_key = key
    return unique
end

local function repeat_count_for_perimeter(perimeter, guide_count)
    if guide_count < 1 then
        return 1
    end
    local max_repeat = math.max(1, math.floor(perimeter / guide_count))
    local desired = 1 + math.floor(math.max(0, perimeter - guide_count) / state.opts.repeat_threshold)
    return math.max(1, math.min(desired, max_repeat))
end

local function gradient_color(guides, t)
    local count = #guides
    if count == 0 then
        return "#ffffff"
    end
    if count == 1 then
        return guides[1]
    end

    local wrapped = t - math.floor(t)
    local scaled = wrapped * count
    local i1 = math.floor(scaled) + 1
    local i2 = (i1 % count) + 1
    local blend_t = scaled - math.floor(scaled)
    return blend_hex(guides[i1], guides[i2], blend_t)
end

local function path_gradient_color(guides, perimeter, repeats, index)
    local normalized = ((index - 1 + state.phase) / math.max(1, perimeter)) * repeats
    return gradient_color(guides, normalized)
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
            if mapped == nil then
                return nil
            end
            local copied = {}
            for i = 1, 8 do
                copied[i] = mapped[i]
            end
            return copied
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
        local truncated = {}
        for i = 1, 8 do
            truncated[i] = chars[i]
        end
        chars = truncated
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

local function to_int(value)
    if type(value) ~= "number" then
        return nil
    end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function resolve_float_box(winid, cfg)
    if cfg.relative == "editor"
        and type(cfg.row) == "number"
        and type(cfg.col) == "number"
        and type(cfg.width) == "number"
        and type(cfg.height) == "number" then
        local row = to_int(cfg.row)
        local col = to_int(cfg.col)
        local width = math.max(1, math.floor(cfg.width))
        local height = math.max(1, math.floor(cfg.height))
        if row and col then
            return {
                row = row,
                col = col,
                width = width,
                height = height,
            }
        end
    end

    local pos = vim.api.nvim_win_get_position(winid)
    if not pos or #pos < 2 then
        return nil
    end
    local width = vim.api.nvim_win_get_width(winid)
    local height = vim.api.nvim_win_get_height(winid)
    if width < 1 or height < 1 then
        return nil
    end
    return {
        row = pos[1],
        col = pos[2],
        width = width,
        height = height,
    }
end

local function get_winhighlight(winid)
    local ok, value = pcall(vim.api.nvim_get_option_value, "winhighlight", { win = winid })
    if ok and type(value) == "string" then
        return value
    end
    local ok_legacy, legacy = pcall(vim.api.nvim_win_get_option, winid, "winhl")
    if ok_legacy and type(legacy) == "string" then
        return legacy
    end
    return ""
end

local function parse_winhighlight(value)
    local mapping = {}
    if type(value) ~= "string" or value == "" then
        return mapping
    end
    for part in value:gmatch("[^,]+") do
        local from, to = part:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
        if from and to and to ~= "" then
            mapping[from] = to
        end
    end
    return mapping
end

local function add_border_group(name, groups, seen)
    if type(name) ~= "string" or name == "" then
        return
    end
    if name:find("^CatppuccinBorderFlow_") then
        return
    end
    if not name:find("Border") then
        return
    end
    if seen[name] then
        return
    end
    seen[name] = true
    table.insert(groups, name)
end

local function add_groups_from_border_config(border, groups, seen)
    if type(border) ~= "table" then
        return
    end
    for _, part in ipairs(border) do
        if type(part) == "table" then
            local hl = part[2]
            add_border_group(hl, groups, seen)
        end
    end
end

local function add_groups_from_buffer_extmarks(bufnr, groups, seen)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    local ok, marks = pcall(vim.api.nvim_buf_get_extmarks, bufnr, -1, 0, -1, { details = true, limit = 512 })
    if not ok or type(marks) ~= "table" then
        return
    end
    for _, mark in ipairs(marks) do
        local details = mark[4]
        local hl_group = details and details.hl_group
        add_border_group(hl_group, groups, seen)
    end
end

local function is_overlay_window(win)
    return state.overlay_wins[win] == true
end

local function create_overlay_window(buf, zindex)
    local opts = {
        relative = "editor",
        row = 0,
        col = 0,
        width = 1,
        height = 1,
        style = "minimal",
        border = "none",
        focusable = false,
        zindex = zindex,
    }
    local win = vim.api.nvim_open_win(buf, false, opts)
    state.overlay_wins[win] = true
    vim.api.nvim_set_option_value("winblend", 0, { win = win })
    vim.api.nvim_set_option_value("number", false, { win = win })
    vim.api.nvim_set_option_value("relativenumber", false, { win = win })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
    vim.api.nvim_set_option_value("cursorline", false, { win = win })
    vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
    vim.api.nvim_set_option_value("winhl", "Normal:NormalFloat,EndOfBuffer:NormalFloat", { win = win })
    return win
end

local function create_overlay_buffer()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = true
    vim.bo[buf].filetype = "catppuccin-borderflow"
    vim.bo[buf].modifiable = false
    vim.b[buf].catppuccin_borderflow_overlay = true
    return buf
end

local function clear_window_state(winid)
    local item = state.windows[winid]
    if not item then
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
    end
    state.windows[winid] = nil
end

local function ensure_sides(winid, zindex)
    local item = state.windows[winid]
    if not item then
        return nil
    end
    local sides = item.sides
    for name, side in pairs(sides) do
        local need_new = true
        if side.buf and vim.api.nvim_buf_is_valid(side.buf) and side.win and vim.api.nvim_win_is_valid(side.win) then
            need_new = false
        end
        if need_new then
            side.buf = create_overlay_buffer()
            side.win = create_overlay_window(side.buf, zindex)
        else
            local cfg = vim.api.nvim_win_get_config(side.win)
            cfg.zindex = zindex
            pcall(vim.api.nvim_win_set_config, side.win, cfg)
        end
        sides[name] = side
    end
    return sides
end

local function set_buffer_lines(buf, lines)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

local function set_overlay_config(win, row, col, width, height, zindex)
    if not vim.api.nvim_win_is_valid(win) then
        return
    end
    local cfg = {
        relative = "editor",
        row = row,
        col = col,
        width = math.max(1, width),
        height = math.max(1, height),
        style = "minimal",
        border = "none",
        focusable = false,
        zindex = zindex,
    }
    pcall(vim.api.nvim_win_set_config, win, cfg)
end

local function refresh_candidates()
    local seen = {}
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        seen[winid] = true
        if not is_overlay_window(winid) then
            local cfg = vim.api.nvim_win_get_config(winid)
            if cfg.relative and cfg.relative ~= "" then
                local buf = vim.api.nvim_win_get_buf(winid)
                if not vim.b[buf].catppuccin_borderflow_overlay then
                    local chars = border_chars(cfg.border)
                    if chars then
                        if not state.windows[winid] then
                            state.windows[winid] = {
                                chars = chars,
                                sides = {
                                    top = {},
                                    right = {},
                                    bottom = {},
                                    left = {},
                                },
                            }
                        else
                            state.windows[winid].chars = chars
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

local function draw_window_border(winid, item)
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
    if border_right < 0 or border_bottom < 0 or border_left > max_col or border_top > max_row then
        clear_window_state(winid)
        return
    end
    if border_left < 0 or border_top < 0 or border_right > max_col or border_bottom > max_row then
        clear_window_state(winid)
        return
    end

    local zindex = (cfg.zindex or 50) + 8
    local sides = ensure_sides(winid, zindex)
    if not sides then
        return
    end

    local total_top = box.width + 2
    local total_bottom = box.width + 2
    local total_side = box.height

    set_overlay_config(sides.top.win, box.row, box.col, total_top, 1, zindex)
    set_overlay_config(sides.bottom.win, box.row + box.height + 1, box.col, total_bottom, 1, zindex)
    set_overlay_config(sides.left.win, box.row + 1, box.col, 1, total_side, zindex)
    set_overlay_config(sides.right.win, box.row + 1, box.col + box.width + 1, 1, total_side, zindex)

    local chars = item.chars
    local tl, t, tr = chars[1] or "", chars[2] or "", chars[3] or ""
    local r, br, b, bl, l = chars[4] or "", chars[5] or "", chars[6] or "", chars[7] or "", chars[8] or ""

    local top_chars = {}
    local top_colors = {}
    local bottom_chars = {}
    local bottom_colors = {}
    local left_chars = {}
    local left_colors = {}
    local right_chars = {}
    local right_colors = {}

    for i = 1, total_top do
        top_chars[i] = " "
        bottom_chars[i] = " "
    end
    for i = 1, total_side do
        left_chars[i] = " "
        right_chars[i] = " "
    end

    local path = {}
    local function push(region, idx, ch)
        if ch ~= "" then
            table.insert(path, { region = region, idx = idx, ch = ch })
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

    local guides = get_palette()
    if #guides == 0 then
        guides = { "#ffffff" }
    end
    local repeats = repeat_count_for_perimeter(#path, #guides)
    for i, p in ipairs(path) do
        local color = path_gradient_color(guides, #path, repeats, i)
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

    set_buffer_lines(sides.top.buf, { table.concat(top_chars) })
    set_buffer_lines(sides.bottom.buf, { table.concat(bottom_chars) })

    local left_lines = {}
    local right_lines = {}
    for i = 1, total_side do
        left_lines[i] = left_chars[i]
        right_lines[i] = right_chars[i]
    end
    set_buffer_lines(sides.left.buf, left_lines)
    set_buffer_lines(sides.right.buf, right_lines)

    local function apply_line(buf, row, colors, chars_by_col)
        vim.api.nvim_buf_clear_namespace(buf, ns, row, row + 1)
        for col = 1, #colors do
            local color = colors[col]
            if color then
                local fill = chars_by_col[col] == " "
                local group = hl_group_for(color, fill)
                pcall(vim.api.nvim_buf_add_highlight, buf, ns, group, row, col - 1, col)
            end
        end
    end

    apply_line(sides.top.buf, 0, top_colors, top_chars)
    apply_line(sides.bottom.buf, 0, bottom_colors, bottom_chars)

    vim.api.nvim_buf_clear_namespace(sides.left.buf, ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(sides.right.buf, ns, 0, -1)
    for i = 1, total_side do
        if left_colors[i] then
            local fill = left_chars[i] == " "
            local group = hl_group_for(left_colors[i], fill)
            pcall(vim.api.nvim_buf_add_highlight, sides.left.buf, ns, group, i - 1, 0, 1)
        end
        if right_colors[i] then
            local fill = right_chars[i] == " "
            local group = hl_group_for(right_colors[i], fill)
            pcall(vim.api.nvim_buf_add_highlight, sides.right.buf, ns, group, i - 1, 0, 1)
        end
    end
end

local function collect_border_groups(force_reset_base)
    local previous_groups = vim.deepcopy(state.border_groups or {})
    local groups = {}
    local seen = {}

    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(winid) and not is_overlay_window(winid) then
            local cfg = vim.api.nvim_win_get_config(winid)
            if cfg.relative and cfg.relative ~= "" then
                local chars = border_chars(cfg.border)
                add_groups_from_border_config(cfg.border, groups, seen)

                local map = parse_winhighlight(get_winhighlight(winid))
                add_border_group(map.FloatBorder, groups, seen)

                if not chars then
                    local buf = vim.api.nvim_win_get_buf(winid)
                    add_groups_from_buffer_extmarks(buf, groups, seen)
                end
            end
        end
    end

    table.sort(groups)

    if force_reset_base then
        for _, name in ipairs(previous_groups) do
            local base = state.border_group_base and state.border_group_base[name]
            if base then
                pcall(vim.api.nvim_set_hl, 0, name, base)
            end
        end
    else
        for _, name in ipairs(previous_groups) do
            if not seen[name] then
                local base = state.border_group_base and state.border_group_base[name]
                if base then
                    pcall(vim.api.nvim_set_hl, 0, name, base)
                end
            end
        end
    end

    if force_reset_base then
        state.border_group_base = {}
    end
    state.border_group_base = state.border_group_base or {}

    for _, name in ipairs(groups) do
        if state.border_group_base[name] == nil then
            local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
            if ok and type(hl) == "table" then
                state.border_group_base[name] = hl
            else
                state.border_group_base[name] = {}
            end
        end
    end

    state.border_groups = groups
end

local function animate_border_groups()
    if #state.border_groups == 0 then
        return
    end
    local guides = get_palette()
    if #guides == 0 then
        return
    end

    local group_count = #state.border_groups
    local repeats = repeat_count_for_perimeter(math.max(group_count, #guides), #guides)

    for i, group in ipairs(state.border_groups) do
        local t = (((i - 1) / math.max(1, group_count)) * repeats) + (state.phase / math.max(1, group_count))
        local color = gradient_color(guides, t)
        local base = state.border_group_base[group] or {}
        local spec = {}
        for k, v in pairs(base) do
            spec[k] = v
        end
        spec.link = nil
        spec.fg = color
        pcall(vim.api.nvim_set_hl, 0, group, spec)
    end
end

local function tick()
    if state.in_tick then
        return
    end
    state.in_tick = true

    local ok, err = pcall(function()
        refresh_candidates()
        collect_border_groups(false)
        for winid, item in pairs(state.windows) do
            if vim.api.nvim_win_is_valid(winid) then
                draw_window_border(winid, item)
            else
                clear_window_state(winid)
            end
        end
        animate_border_groups()
        state.phase = state.phase + state.opts.phase_step

        local mode = vim.api.nvim_get_mode().mode
        if type(mode) == "string" and mode:sub(1, 1) == "c" then
            pcall(vim.api.nvim_command, "redraw")
        end
    end)

    state.in_tick = false
    if not ok then
        vim.schedule(function()
            vim.notify("Borderflow tick failed: " .. tostring(err), vim.log.levels.WARN)
        end)
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
    collect_border_groups(true)
    tick()
    queue_tick()
end

function M.stop()
    if state.timer then
        state.timer:stop()
        state.timer:close()
        state.timer = nil
    end
    for winid, _ in pairs(state.windows) do
        clear_window_state(winid)
    end
    state.windows = {}
    state.overlay_wins = {}
    for group, base in pairs(state.border_group_base) do
        pcall(vim.api.nvim_set_hl, 0, group, base)
    end
end

function M.start()
    if not state.opts or not state.opts.enabled then
        return
    end
    if state.timer then
        return
    end
    state.timer = uv.new_timer()
    state.timer:start(0, state.opts.frame_ms, vim.schedule_wrap(tick))
    queue_tick()
end

function M.enable()
    state.opts.enabled = true
    M.start()
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
    state.hl_cache = {}
    state.windows = {}
    state.overlay_wins = {}
    state.guides = {}
    state.guide_key = nil
    state.in_tick = false
    state.tick_queued = false
    if state.augroup then
        pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    end
    state.augroup = vim.api.nvim_create_augroup("CatppuccinBorderFlow", { clear = true })

    vim.api.nvim_create_autocmd("ColorScheme", {
        group = state.augroup,
        callback = function()
            M.refresh()
        end,
    })

    vim.api.nvim_create_autocmd({ "VimResized", "WinClosed" }, {
        group = state.augroup,
        callback = function()
            if state.opts and state.opts.enabled then
                tick()
            end
            queue_tick()
        end,
    })

    vim.api.nvim_create_autocmd({ "WinNew", "WinEnter", "BufWinEnter", "CmdlineEnter", "CmdlineChanged", "ModeChanged" }, {
        group = state.augroup,
        callback = function()
            if state.opts and state.opts.enabled then
                tick()
            end
            queue_tick()
        end,
    })

    vim.api.nvim_create_user_command("CatppuccinBorderFlowToggle", function()
        M.toggle()
    end, { desc = "Toggle Catppuccin border animation" })

    vim.api.nvim_create_user_command("CatppuccinBorderFlowRefresh", function()
        M.refresh()
    end, { desc = "Refresh Catppuccin border animation state" })

    _G.__refresh_catppuccin_borderflow = function()
        M.refresh()
    end

    collect_border_groups(true)
    if state.opts.enabled then
        M.start()
    end
end

return M
