#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
SETUP="$ROOT/linux-setup.sh"
BASH_BIN="${BASH_BIN:-$(command -v bash)}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/linux-setup-test.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_exists() { [[ -e "$1" || -L "$1" ]] || fail "missing $1"; }
assert_missing() { [[ ! -e "$1" && ! -L "$1" ]] || fail "unexpected $1"; }
assert_contains() { grep -Fqx -- "$2" "$1" >/dev/null || fail "$1 does not contain $2"; }

run_setup() {
    local home="$1" fakebin="$1/fakebin"; shift
    mkdir -p "$fakebin"
    printf '%s\n' '#!/bin/sh' 'printf "%s\\n" Linux' >"$fakebin/uname"
    chmod +x "$fakebin/uname"
    HOME="$home" XDG_CONFIG_HOME="$home/config" XDG_DATA_HOME="$home/data" PATH="$fakebin:$PATH" "$BASH_BIN" "$SETUP" --no-packages --no-neovim-bootstrap "$@"
}

new_home() { local home="$TMP/$1"; mkdir -p "$home"; printf '%s\n' "$home"; }

test_clean_install_all_mappings() {
    local home component target
    home="$(new_home clean)"
    run_setup "$home"
    for component in nvim kitty alacritty btop lazygit yazi espanso; do assert_exists "$home/config/$component"; done
    assert_exists "$home/.zshrc"; assert_exists "$home/.tmux.conf"; assert_exists "$home/.p10k.zsh"; assert_exists "$home/config/starship.toml"
    [[ -f "$home/config/nvim/init.lua" ]] || fail 'nvim init.lua not installed'
    cmp -s "$ROOT/zshrc" "$home/.zshrc" || fail 'installed zsh config does not match root zshrc'
    cmp -s "$ROOT/.p10k.zsh" "$home/.p10k.zsh" || fail 'installed p10k config does not match root .p10k.zsh'
}

test_existing_skip_and_backup() {
    local home backup
    home="$(new_home existing)"; mkdir -p "$home/config/kitty"; printf old >"$home/config/kitty/sentinel"
    run_setup "$home" --components kitty
    assert_exists "$home/config/kitty/sentinel"
    run_setup "$home" --components kitty --backup-existing
    assert_missing "$home/config/kitty/sentinel"; assert_exists "$home/config/kitty/kitty.conf"
    backup="$(printf '%s\n' "$home"/config/kitty.backup-* | head -n1)"
    assert_exists "$backup/sentinel"
}

test_p10k_existing_skip_and_backup() {
    local home backup
    home="$(new_home p10k)"; printf old >"$home/.p10k.zsh"
    run_setup "$home" --components p10k
    [[ "$(<"$home/.p10k.zsh")" == old ]] || fail 'p10k did not preserve existing file'
    run_setup "$home" --components p10k --backup-existing
    cmp -s "$ROOT/.p10k.zsh" "$home/.p10k.zsh" || fail 'p10k backup replacement did not install root .p10k.zsh'
    backup="$(printf '%s\n' "$home"/.p10k.zsh.backup-* | head -n1)"
    [[ "$(<"$backup")" == old ]] || fail 'p10k backup did not retain existing file'
}

test_copy_and_register_themes() {
    local copy_home register_home source_config source_data manifest copied
    copy_home="$(new_home themes-copy)"; source_config="$copy_home/old-config/nvim"; source_data="$copy_home/old-data/nvim"
    mkdir -p "$source_config/colors" "$source_data/lazy/theme-one/colors" "$source_data/lazy/theme-two/colors"
    printf config >"$source_config/colors/legacy.vim"; printf one >"$source_data/lazy/theme-one/colors/one.vim"; printf two >"$source_data/lazy/theme-two/colors/two.vim"
    run_setup "$copy_home" --components nvim --copy-existing-colorschemes --theme-source-config "$source_config" --theme-source-data "$source_data"
    manifest="$copy_home/config/nvim/imported-colorschemes.txt"; assert_exists "$manifest"
    copied="$(sed -n '2p' "$manifest")"; assert_exists "$copied/colors/legacy.vim"
    copied="$(sed -n '3p' "$manifest")"; assert_exists "$copied/colors/one.vim"
    copied="$(sed -n '4p' "$manifest")"; assert_exists "$copied/colors/two.vim"

    register_home="$(new_home themes-register)"
    run_setup "$register_home" --components nvim --register-existing-colorschemes --theme-source-config "$source_config" --theme-source-data "$source_data"
    manifest="$register_home/config/nvim/imported-colorschemes.txt"
    assert_contains "$manifest" "$(cd "$source_config" && pwd -P)"
    assert_contains "$manifest" "$(cd "$source_data/lazy/theme-one" && pwd -P)"
}

test_theme_copy_survives_nvim_backup() {
    local home manifest copied
    home="$(new_home theme-backup)"; mkdir -p "$home/config/nvim/colors"; printf survive >"$home/config/nvim/colors/survive.vim"
    run_setup "$home" --components nvim --backup-existing --copy-existing-colorschemes
    manifest="$home/config/nvim/imported-colorschemes.txt"; copied="$(sed -n '2p' "$manifest")"
    assert_exists "$copied/colors/survive.vim"
    assert_exists "$(printf '%s\n' "$home"/config/nvim.backup-* | head -n1)/colors/survive.vim"
}

test_register_tracks_moved_nvim_backup() {
    local home manifest backup
    home="$(new_home register-backup)"; mkdir -p "$home/config/nvim/colors"; printf register >"$home/config/nvim/colors/register.vim"
    run_setup "$home" --components nvim --backup-existing --register-existing-colorschemes
    manifest="$home/config/nvim/imported-colorschemes.txt"
    backup="$(printf '%s\n' "$home"/config/nvim.backup-* | head -n1)"
    assert_contains "$manifest" "$(cd "$backup" && pwd -P)"
    if grep -Fqx -- "$home/config/nvim" "$manifest" >/dev/null; then
        fail 'manifest retained replaced nvim target'
    fi
}

test_register_keeps_external_symlink_source() {
    local home external manifest backup
    home="$(new_home register-symlink)"; external="$home/external/nvim"
    mkdir -p "$external/colors" "$home/config"; printf external >"$external/colors/external.vim"
    ln -s "$external" "$home/config/nvim"
    run_setup "$home" --components nvim --backup-existing --register-existing-colorschemes
    manifest="$home/config/nvim/imported-colorschemes.txt"
    backup="$(printf '%s\n' "$home"/config/nvim.backup-* | head -n1)"
    assert_contains "$manifest" "$(cd "$external" && pwd -P)"
    if grep -Fqx -- "$backup" "$manifest"; then
        fail 'manifest remapped an external symlink source to backup'
    fi
}

test_errors_dry_run_and_idempotency() {
    local home before after
    home="$(new_home guards)"
    if run_setup "$home" --copy-existing-colorschemes --register-existing-colorschemes >/dev/null 2>&1; then fail 'mutually exclusive theme modes accepted'; fi
    if run_setup "$home" --components kitty --copy-existing-colorschemes >/dev/null 2>&1; then fail 'theme import without nvim accepted'; fi
    run_setup "$home" --components kitty --dry-run
    assert_missing "$home/config/kitty"
    run_setup "$home" --components kitty
    before="$(cksum "$home/config/kitty/kitty.conf")"
    run_setup "$home" --components kitty
    after="$(cksum "$home/config/kitty/kitty.conf")"
    [[ "$before" == "$after" ]] || fail 'second run changed existing target'
}

test_theme_import_requires_backup_for_existing_nvim() {
    local home
    home="$(new_home theme-needs-backup)"
    mkdir -p "$home/config/nvim/colors"
    printf old >"$home/config/nvim/sentinel"
    printf theme >"$home/config/nvim/colors/old.vim"
    if run_setup "$home" --components nvim --copy-existing-colorschemes >/dev/null 2>&1; then
        fail 'theme import replaced existing nvim without --backup-existing'
    fi
    assert_exists "$home/config/nvim/sentinel"
    assert_missing "$home/config/nvim/imported-colorschemes.txt"
}

test_failure_rolls_back_prior_component() {
    local home fakebin backup_count
    home="$(new_home rollback)"; fakebin="$home/fakebin"
    mkdir -p "$home/config/nvim" "$fakebin"
    printf old >"$home/config/nvim/sentinel"
    printf '%s\n' \
        '#!/bin/sh' \
        "count_file='$home/cp-count'" \
        'count=0' \
        '[ ! -r "$count_file" ] || count=$(cat "$count_file")' \
        'count=$((count + 1))' \
        'printf "%s\n" "$count" >"$count_file"' \
        '[ "$count" -lt 2 ] || exit 73' \
        'exec /bin/cp "$@"' >"$fakebin/cp"
    chmod +x "$fakebin/cp"
    if run_setup "$home" --components nvim,kitty --backup-existing >/dev/null 2>&1; then
        fail 'fault-injected install unexpectedly succeeded'
    fi
    assert_exists "$home/config/nvim/sentinel"
    assert_missing "$home/config/kitty"
    backup_count="$(printf '%s\n' "$home"/config/nvim.backup-* | grep -vc '\*' || true)"
    [[ "$backup_count" == 0 ]] || fail 'rollback left an nvim backup behind'
}

test_clean_install_all_mappings
test_existing_skip_and_backup
test_p10k_existing_skip_and_backup
test_copy_and_register_themes
test_theme_copy_survives_nvim_backup
test_register_tracks_moved_nvim_backup
test_register_keeps_external_symlink_source
test_errors_dry_run_and_idempotency
test_theme_import_requires_backup_for_existing_nvim
test_failure_rolls_back_prior_component
printf 'PASS: linux-setup tests\n'
