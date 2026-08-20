#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
INIT="$ROOT/nvim/init.lua"
NVIM_BIN="${NVIM_BIN:-$(command -v nvim)}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/nvim-colourscheme-test.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() { grep -Fq -- "$2" "$1" || fail "$1 missing $2"; }
assert_absent() { ! grep -Fq -- "$2" "$1" || fail "$1 unexpectedly contains $2"; }

[[ -x "$NVIM_BIN" ]] || fail 'nvim is required'

runtime_root="$TMP/imported-runtime"
config_home="$TMP/config"
mkdir -p "$runtime_root/colors" "$config_home/nvim" "$TMP/state" "$TMP/home"
printf '%s\n' 'vim.api.nvim_set_hl(0, "Normal", { fg = "#aabbcc", bg = "#112233" })' >"$runtime_root/colors/ImportedCase.lua"
printf '%s\n' \
    '# absolute runtime roots only' \
    "$runtime_root" \
    "$runtime_root" \
    'relative/runtime' \
    "$TMP/stale-runtime" >"$config_home/nvim/imported-colorschemes.txt"

lua_test="$TMP/assert-imported.lua"
printf '%s\n' \
    'local ok, err = xpcall(function()' \
    '  local schemes = require("imported_colorschemes").load()' \
    '  assert(#schemes == 1, vim.inspect(schemes))' \
    '  assert(schemes[1].name == "ImportedCase", vim.inspect(schemes[1]))' \
    '  assert(schemes[1].id:match("^imported:[0-9a-f]+:ImportedCase$"), schemes[1].id)' \
    "  assert(vim.tbl_contains(vim.api.nvim_list_runtime_paths(), vim.uv.fs_realpath(\"$runtime_root\")))" \
    '  vim.cmd.colorscheme(schemes[1].name)' \
    '  assert(vim.api.nvim_get_hl(0, { name = "Normal" }).fg == 0xaabbcc)' \
    'end, debug.traceback)' \
    'if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") end' \
    'print("PASS: imported colourschemes")' \
    'vim.cmd("qa!")' >"$lua_test"

(
    cd "$TMP"
    HOME="$TMP/home" XDG_CONFIG_HOME="$config_home" XDG_STATE_HOME="$TMP/state" NVIM_LOG_FILE="$TMP/nvim.log" \
        "$NVIM_BIN" --headless -u NONE --cmd "set rtp^=$ROOT/nvim" \
        "+luafile $lua_test"
)

assert_contains "$INIT" 'builtin_colorscheme_names["catppuccin"] = true'
assert_contains "$INIT" 'builtin_colorscheme_names["catppuccin-" .. spec.catppuccin] = true'
assert_contains "$INIT" 'builtin_colorscheme_names[spec.catppuccin] = true'
assert_contains "$INIT" '{ "<leader>uC",      choose_catppuccin_flavour'
assert_contains "$INIT" 'vim.keymap.set("n", "<leader>uC", choose_catppuccin_flavour'
assert_contains "$INIT" '"set-colors",'
assert_contains "$INIT" 'kitty_current_theme_file,'
for forbidden in KittyOpacity KittyThemeSync prompt_kitty_opacity kitty-opacity kitty-wallpaper sync_desktop 'Snacks.picker.colorschemes' 'Snacks.toggle.option("background"' '"load-config"' '"--reload-in=all"' '<leader>co' '<leader>ub'; do
    assert_absent "$INIT" "$forbidden"
done

printf 'PASS: nvim colourscheme tests\n'
