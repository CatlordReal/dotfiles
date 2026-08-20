#!/usr/bin/env bash
# Install Linux-supported configurations from this repository.  Bash 4+ only.
set -Eeuo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
    printf 'linux-setup: Bash 4 or newer is required.\n' >&2
    exit 2
fi

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly DEFAULT_COMPONENTS=(nvim kitty alacritty btop lazygit yazi zsh tmux p10k starship espanso)
readonly JETBRAINS_NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.0/JetBrainsMono.tar.xz"
readonly JETBRAINS_NERD_FONT_SHA256="0227b220360a6f819b9ead92343e8112b34733054782561af50cfba1e8afab63"

DRY_RUN=0
NO_PACKAGES=0
NO_NEOVIM_BOOTSTRAP=0
BACKUP_EXISTING=0
THEME_MODE=""
THEME_SOURCE_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
THEME_SOURCE_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
declare -a COMPONENTS=() THEME_ROOTS=() IMPORTED_ROOTS=() INSTALLED_TARGETS=() BACKUP_TARGETS=() BACKUP_PATHS=() CREATED_ARTIFACTS=() STAGE_DIRS=() PACKAGE_ORDER=()
declare -A SELECTED_PACKAGES=() REQUIRED_SELECTED_PACKAGES=()
COMMITTED=0

log() { printf '[linux-setup] %s\n' "$*"; }
warn() { printf '[linux-setup] warning: %s\n' "$*" >&2; }
die() { printf '[linux-setup] error: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: linux-setup.sh [options]

Install Linux-supported dotfiles. Existing targets are left unchanged unless
--backup-existing is supplied.

  --components LIST                     Comma-separated components (default: all)
  --backup-existing                     Move existing targets to timestamped backups
  --no-packages                         Do not use apt-get
  --no-neovim-bootstrap                 Do not run Lazy sync after installation
  --copy-existing-colorschemes          Snapshot discovered runtime roots into nvim data
  --register-existing-colorschemes      Reference discovered runtime roots from nvim
  --theme-source-config PATH            Existing nvim configuration root to inspect
  --theme-source-data PATH              Existing nvim data root to inspect
  --dry-run                             Print mutations without making them
  -h, --help                            Show this help
EOF
}

shell_join() { local x; for x in "$@"; do printf '%q ' "$x"; done; }
run() {
    log "+ $(shell_join "$@")"
    (( DRY_RUN )) || "$@"
}

contains_component() {
    local wanted="$1" item
    for item in "${COMPONENTS[@]}"; do [[ "$item" == "$wanted" ]] && return 0; done
    return 1
}

canonical_existing() {
    [[ -d "$1" ]] || return 1
    (cd -- "$1" && pwd -P)
}

absolute_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$PWD" "$1" ;;
    esac
}

path_within() {
    local path="$1" root="$2"
    [[ "$path" == "$root" || "$path" == "$root"/* ]]
}

has_dot_segment() {
    case "/$1/" in
        */./*|*/../*) return 0 ;;
        *) return 1 ;;
    esac
}

safe_remove() {
    local path="$1" root="$2"
    [[ -n "$path" && "$path" != / && "$path" != "$root" ]] || die "refusing unsafe removal: $path"
    path_within "$path" "$root" || die "refusing removal outside $root: $path"
    [[ -e "$path" || -L "$path" ]] || return 0
    run rm -rf -- "$path"
}

rollback() {
    local i
    (( COMMITTED )) && return 0
    (( DRY_RUN )) && return 0
    warn "installation interrupted; restoring changed configuration targets"
    for ((i=${#STAGE_DIRS[@]} - 1; i >= 0; i--)); do
        safe_remove "${STAGE_DIRS[i]}" "${STAGE_DIRS[i]%/*}" || true
    done
    for ((i=${#INSTALLED_TARGETS[@]} - 1; i >= 0; i--)); do
        safe_remove "${INSTALLED_TARGETS[i]}" "${INSTALLED_TARGETS[i]%/*}" || true
    done
    for ((i=${#BACKUP_TARGETS[@]} - 1; i >= 0; i--)); do
        if [[ -e "${BACKUP_PATHS[i]}" || -L "${BACKUP_PATHS[i]}" ]]; then
            mv -- "${BACKUP_PATHS[i]}" "${BACKUP_TARGETS[i]}" || true
        fi
    done
    for ((i=${#CREATED_ARTIFACTS[@]} - 1; i >= 0; i--)); do
        safe_remove "${CREATED_ARTIFACTS[i]}" "${CREATED_ARTIFACTS[i]%/*}" || true
    done
}
trap rollback ERR INT TERM

parse_args() {
    local list item
    while (( $# )); do
        case "$1" in
            --components)
                (( $# >= 2 )) || die "--components needs a value"
                list="$2"; IFS=',' read -r -a COMPONENTS <<<"$list"
                for item in "${COMPONENTS[@]}"; do
                    [[ -n "$item" ]] || die "empty component in --components"
                    case "$item" in nvim|kitty|alacritty|btop|lazygit|yazi|zsh|tmux|p10k|starship|espanso) ;; *) die "unknown component: $item";; esac
                done
                shift 2
                continue
                ;;
            --backup-existing) BACKUP_EXISTING=1 ;;
            --no-packages) NO_PACKAGES=1 ;;
            --no-neovim-bootstrap) NO_NEOVIM_BOOTSTRAP=1 ;;
            --copy-existing-colorschemes) [[ -z "$THEME_MODE" ]] || die "theme import modes are mutually exclusive"; THEME_MODE=copy ;;
            --register-existing-colorschemes) [[ -z "$THEME_MODE" ]] || die "theme import modes are mutually exclusive"; THEME_MODE=register ;;
            --theme-source-config) (( $# >= 2 )) || die "--theme-source-config needs a path"; THEME_SOURCE_CONFIG="$2"; shift 2; continue ;;
            --theme-source-data) (( $# >= 2 )) || die "--theme-source-data needs a path"; THEME_SOURCE_DATA="$2"; shift 2; continue ;;
            --dry-run) DRY_RUN=1 ;;
            -h|--help) usage; exit 0 ;;
            *) die "unknown option: $1" ;;
        esac
        shift
    done
    (( ${#COMPONENTS[@]} )) || COMPONENTS=("${DEFAULT_COMPONENTS[@]}")
}

target_for() {
    local component="$1"
    case "$component" in
        nvim|kitty|alacritty|btop|lazygit|yazi|espanso) printf '%s/%s\n' "$XDG_CONFIG_HOME_VALUE" "$component" ;;
        zsh) printf '%s/.zshrc\n' "$HOME" ;;
        tmux) printf '%s/.tmux.conf\n' "$HOME" ;;
        p10k) printf '%s/.p10k.zsh\n' "$HOME" ;;
        starship) printf '%s/starship.toml\n' "$XDG_CONFIG_HOME_VALUE" ;;
    esac
}

source_for() {
    local component="$1"
    case "$component" in
        zsh) printf '%s/zshrc\n' "$SCRIPT_DIR" ;;
        tmux) printf '%s/.tmux.conf\n' "$SCRIPT_DIR" ;;
        p10k) printf '%s/.p10k.zsh\n' "$SCRIPT_DIR" ;;
        starship) printf '%s/starship.toml\n' "$SCRIPT_DIR" ;;
        *) printf '%s/%s\n' "$SCRIPT_DIR" "$component" ;;
    esac
}

remap_theme_roots() {
    local old_root="$1" new_root="$2" index root suffix
    [[ -n "$old_root" && -n "$new_root" ]] || return 0
    for ((index=0; index < ${#THEME_ROOTS[@]}; index++)); do
        root="${THEME_ROOTS[index]}"
        if [[ "$root" == "$old_root" ]]; then
            THEME_ROOTS[index]="$new_root"
        elif [[ "$root" == "$old_root"/* ]]; then
            suffix="${root#"$old_root"}"
            THEME_ROOTS[index]="$new_root$suffix"
        fi
    done
}

preflight_targets() {
    local component source target
    [[ -n "${HOME:-}" && "$HOME" == /* && "$HOME" != / ]] || die "HOME must be a non-root absolute path"
    XDG_CONFIG_HOME_VALUE="$(absolute_path "${XDG_CONFIG_HOME:-$HOME/.config}")"
    XDG_DATA_HOME_VALUE="$(absolute_path "${XDG_DATA_HOME:-$HOME/.local/share}")"
    [[ "$XDG_CONFIG_HOME_VALUE" != / && "$XDG_DATA_HOME_VALUE" != / ]] || die "XDG paths must not be root"
    if has_dot_segment "$HOME" || has_dot_segment "$XDG_CONFIG_HOME_VALUE" || has_dot_segment "$XDG_DATA_HOME_VALUE"; then
        die "HOME and XDG paths must not contain . or .. segments"
    fi
    for component in "${COMPONENTS[@]}"; do
        source="$(source_for "$component")"; target="$(target_for "$component")"
        [[ -e "$source" || -L "$source" ]] || die "missing repository source for $component: $source"
        case "$component" in
            zsh|tmux|p10k) path_within "$target" "$HOME" || die "unsafe target for $component: $target" ;;
            *) path_within "$target" "$XDG_CONFIG_HOME_VALUE" || die "unsafe target for $component: $target" ;;
        esac
    done
}

add_theme_root() {
    local candidate canonical seen
    candidate="$1"
    [[ -d "$candidate/colors" ]] || return 0
    canonical="$(canonical_existing "$candidate")" || return 0
    for seen in "${THEME_ROOTS[@]}"; do [[ "$seen" == "$canonical" ]] && return 0; done
    THEME_ROOTS+=("$canonical")
}

discover_theme_roots() {
    local config data plugin
    config="$(canonical_existing "$THEME_SOURCE_CONFIG" || true)"
    data="$(canonical_existing "$THEME_SOURCE_DATA" || true)"
    [[ -n "$config" ]] && add_theme_root "$config"
    if [[ -n "$config" ]]; then
        for plugin in "$config"/lazy/*; do [[ -d "$plugin" ]] && add_theme_root "$plugin"; done
    fi
    if [[ -n "$data" ]]; then
        for plugin in "$data"/lazy/*; do [[ -d "$plugin" ]] && add_theme_root "$plugin"; done
    fi
    if (( ${#THEME_ROOTS[@]} == 0 )); then
        warn "no existing colourscheme runtime roots found"
    fi
}

copy_theme_roots() {
    local root destination index=0 label
    destination="$XDG_DATA_HOME_VALUE/nvim/imported-colorschemes"
    if (( DRY_RUN )); then
        for root in "${THEME_ROOTS[@]}"; do log "Would copy colourscheme runtime root $root into $destination"; done
        return
    fi
    mkdir -p -- "$destination"
    for root in "${THEME_ROOTS[@]}"; do
        label="$(basename "$root")-$index"
        while [[ -e "$destination/$label" ]]; do index=$((index + 1)); label="$(basename "$root")-$index"; done
        CREATED_ARTIFACTS+=("$destination/$label")
        cp -a -- "$root" "$destination/$label"
        IMPORTED_ROOTS+=("$(canonical_existing "$destination/$label")")
        index=$((index + 1))
    done
}

write_theme_manifest() {
    local manifest="$XDG_CONFIG_HOME_VALUE/nvim/imported-colorschemes.txt" root tmp
    local -a roots=()
    [[ -n "$THEME_MODE" ]] || return 0
    if [[ "$THEME_MODE" == copy ]]; then roots=("${IMPORTED_ROOTS[@]}"); else roots=("${THEME_ROOTS[@]}"); fi
    if (( DRY_RUN )); then log "Would write colourscheme manifest $manifest"; return; fi
    mkdir -p -- "$(dirname -- "$manifest")"
    tmp="$(mktemp "${TMPDIR:-/tmp}/linux-setup-manifest.XXXXXX")"
    printf '# Generated by linux-setup.sh (%s). One absolute runtime root per line.\n' "$THEME_MODE" >"$tmp"
    for root in "${roots[@]}"; do printf '%s\n' "$root" >>"$tmp"; done
    mv -- "$tmp" "$manifest"
    CREATED_ARTIFACTS+=("$manifest")
}

install_component() {
    local component="$1" source target parent stage backup stamp target_canonical backup_canonical
    source="$(source_for "$component")"; target="$(target_for "$component")"; parent="$(dirname -- "$target")"
    if [[ -e "$target" || -L "$target" ]]; then
        if (( ! BACKUP_EXISTING )); then log "Keeping existing $component target: $target"; return; fi
        target_canonical=""
        if [[ "$component" == nvim && "$THEME_MODE" == register && -d "$target" && ! -L "$target" ]]; then
            target_canonical="$(canonical_existing "$target")"
        fi
        stamp="$(date +%Y%m%d%H%M%S)"
        backup="${target}.backup-${stamp}"
        while [[ -e "$backup" || -L "$backup" ]]; do backup="${target}.backup-${stamp}-$RANDOM"; done
        run mkdir -p -- "$parent"
        run mv -- "$target" "$backup"
        BACKUP_TARGETS+=("$target"); BACKUP_PATHS+=("$backup")
        if [[ -n "$target_canonical" && $DRY_RUN -eq 0 ]]; then
            backup_canonical="$(canonical_existing "$backup")"
            remap_theme_roots "$target_canonical" "$backup_canonical"
        fi
    fi
    if (( DRY_RUN )); then
        stage="${TMPDIR:-/tmp}/linux-setup-stage.dry-run"
    else
        stage="$(mktemp -d "${TMPDIR:-/tmp}/linux-setup-stage.XXXXXX")"
        STAGE_DIRS+=("$stage")
    fi
    run cp -a -- "$source" "$stage/payload"
    run mkdir -p -- "$parent"
    run mv -- "$stage/payload" "$target"
    INSTALLED_TARGETS+=("$target")
    (( DRY_RUN )) || rmdir -- "$stage" 2>/dev/null || true
}

require_kali_apt() {
    require_linux
    command -v apt-get >/dev/null 2>&1 || die "package installation requires apt-get"
    [[ -r /etc/os-release ]] || die "cannot verify Kali Linux: /etc/os-release missing"
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == kali ]] || die "automatic package installation supports Kali Linux only; use --no-packages elsewhere"
}

require_linux() { [[ "$(uname -s)" == Linux ]] || die "linux-setup supports Linux only"; }
package_installed() { dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null | grep -qx installed; }
package_available() { apt-cache show "$1" >/dev/null 2>&1; }

add_package() {
    local package="$1" required="$2"
    if [[ -z "${SELECTED_PACKAGES[$package]:-}" ]]; then
        SELECTED_PACKAGES[$package]=1
        PACKAGE_ORDER+=("$package")
    fi
    [[ "$required" == yes ]] && REQUIRED_SELECTED_PACKAGES[$package]=1
    return 0
}

select_component_packages() {
    local component package
    for component in "${COMPONENTS[@]}"; do
        case "$component" in
            nvim)
                for package in neovim git curl ca-certificates build-essential pkg-config unzip tar gzip xz-utils ripgrep fd-find fzf jq python3 python3-pip python3-venv nodejs npm sqlite3 libsqlite3-dev libxml2-utils xdg-utils lua5.1 luarocks; do add_package "$package" yes; done
                ;;
            kitty|alacritty)
                add_package "$component" yes
                for package in ca-certificates curl xz-utils fontconfig tar; do add_package "$package" yes; done
                ;;
            btop) add_package btop yes ;;
            lazygit|yazi|starship|espanso) add_package "$component" no ;;
            zsh) for package in zsh fzf zoxide; do add_package "$package" yes; done ;;
            tmux) add_package tmux yes ;;
            p10k) add_package zsh-theme-powerlevel10k no ;;
        esac
    done
}

terminal_selected() { contains_component kitty || contains_component alacritty; }

font_family_installed() {
    command -v fc-list >/dev/null 2>&1 && fc-list : family | grep -qi 'JetBrainsMono Nerd Font'
}

install_jetbrains_nerd_font() {
    local font_root font_dir archive
    terminal_selected || return 0
    if font_family_installed; then
        log "JetBrainsMono Nerd Font already available"
        return 0
    fi
    font_root="$XDG_DATA_HOME_VALUE/fonts"
    font_dir="$font_root/JetBrainsMonoNerdFont"
    path_within "$font_dir" "$XDG_DATA_HOME_VALUE" || die "unsafe font target: $font_dir"
    if [[ -e "$font_dir" || -L "$font_dir" ]]; then
        warn "JetBrainsMono Nerd Font directory exists but family is not registered; leaving it unchanged: $font_dir"
        return 0
    fi
    if (( DRY_RUN )); then
        log "Would download and verify JetBrainsMono Nerd Font v3.5.0 into $font_dir"
        return 0
    fi
    command -v curl >/dev/null 2>&1 || die "curl is required to download JetBrainsMono Nerd Font"
    command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required to verify JetBrainsMono Nerd Font"
    command -v tar >/dev/null 2>&1 || die "tar is required to install JetBrainsMono Nerd Font"
    command -v fc-cache >/dev/null 2>&1 || die "fontconfig is required to install JetBrainsMono Nerd Font"
    archive="$(mktemp "${TMPDIR:-/tmp}/linux-setup-jetbrainsmono.XXXXXX.tar.xz")"
    CREATED_ARTIFACTS+=("$archive")
    run curl --fail --location --retry 3 --output "$archive" "$JETBRAINS_NERD_FONT_URL"
    printf '%s  %s\n' "$JETBRAINS_NERD_FONT_SHA256" "$archive" | sha256sum -c -
    run mkdir -p -- "$font_root"
    run mkdir -- "$font_dir"
    CREATED_ARTIFACTS+=("$font_dir")
    run tar -xJf "$archive" -C "$font_dir"
    run fc-cache -f "$font_dir"
    safe_remove "$archive" "${archive%/*}"
}

install_packages() {
    local package missing=0
    local -a available=()
    require_kali_apt
    select_component_packages
    for package in "${PACKAGE_ORDER[@]}"; do
        if ! package_installed "$package"; then missing=1; fi
    done
    if (( missing )); then
        if (( EUID == 0 )); then
            run apt-get update
        elif command -v sudo >/dev/null 2>&1; then
            run sudo apt-get update
        else
            die "sudo is required to install apt packages"
        fi
        for package in "${PACKAGE_ORDER[@]}"; do
            package_installed "$package" && continue
            if package_available "$package"; then available+=("$package");
            elif [[ -n "${REQUIRED_SELECTED_PACKAGES[$package]:-}" ]]; then die "required apt package unavailable: $package"
            else warn "optional apt package unavailable, skipping: $package"; fi
        done
        if (( ${#available[@]} )); then
            if (( EUID == 0 )); then
                run apt-get install -y -- "${available[@]}"
            else
                run sudo apt-get install -y -- "${available[@]}"
            fi
        fi
    else
        log "All selected apt packages already installed"
    fi
    install_jetbrains_nerd_font
}

bootstrap_neovim() {
    contains_component nvim || return 0
    (( NO_NEOVIM_BOOTSTRAP )) && return 0
    if ! command -v nvim >/dev/null 2>&1; then warn "nvim is unavailable; skipped Lazy sync"; return; fi
    log "Syncing Neovim plugins with Lazy"
    if (( DRY_RUN )); then log "+ nvim --headless '+Lazy! sync' +qa"; return; fi
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME_VALUE" XDG_DATA_HOME="$XDG_DATA_HOME_VALUE" nvim --headless '+Lazy! sync' +qa
}

main() {
    parse_args "$@"
    require_linux
    preflight_targets
    if [[ -n "$THEME_MODE" ]]; then
        contains_component nvim || die "colourscheme import requires the nvim component"
        if [[ ( -e "$XDG_CONFIG_HOME_VALUE/nvim" || -L "$XDG_CONFIG_HOME_VALUE/nvim" ) && $BACKUP_EXISTING -eq 0 ]]; then
            die "colourscheme import would replace an existing nvim target; add --backup-existing"
        fi
        case "$THEME_SOURCE_CONFIG:$THEME_SOURCE_DATA" in
            *$'\n'*) die "theme source paths must not contain newlines" ;;
        esac
    fi
    [[ -z "$THEME_MODE" ]] || discover_theme_roots
    (( NO_PACKAGES )) || install_packages
    # Copy before replacing nvim, preserving a source rooted at the old target.
    [[ "$THEME_MODE" == copy ]] && copy_theme_roots
    local component
    for component in "${COMPONENTS[@]}"; do install_component "$component"; done
    [[ -n "$THEME_MODE" ]] && write_theme_manifest
    bootstrap_neovim
    COMMITTED=1
    log "Complete"
}

main "$@"
