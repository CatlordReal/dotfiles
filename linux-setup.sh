#!/usr/bin/env bash
set -Eeuo pipefail

# Safe Linux entrypoint. Installs this repository's Neovim config and its
# command-line dependencies without touching the active config unless the
# caller explicitly permits a backup-and-replace.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_CONFIG_DIR="$ROOT_DIR/nvim"
TARGET_CONFIG_DIR="${NVIM_TARGET_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/nvim}"
INSTALL_CONFIG=1
BACKUP_EXISTING=0
DRY_RUN=0
SETUP_ARGS=()

die() {
    printf '[linux-setup] error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: ./linux-setup.sh [options]

Installs Linux packages, Neovim, language tooling, plugins, and this nvim config.

Options:
  --config-dir PATH            Install config at PATH instead of ~/.config/nvim
  --backup-existing-config     Move an existing target config to a timestamped backup
  --no-config-install            Use repository config only; do not copy it
  --no-extra-runtimes           Skip optional lazygit, gh, Rust, and Java packages
  --with-cli-tools               Also install CLI tools, tmux, JetBrainsMono NF, and Powerlevel10k
  --with-font                    Also install JetBrainsMono Nerd Font
  --with-p10k                    Also install Powerlevel10k and ~/.p10k.zsh
  --with-tmux                    Also install tmux and ~/.tmux.conf
  --with-zshrc                   Also install the repository zshrc as ~/.zshrc
  --no-aux-config-install        Install optional software, but do not copy shell/tmux config files
  --dry-run                     Show actions without changing the machine
  --help                        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config-dir)
            [[ $# -ge 2 ]] || die "--config-dir requires PATH"
            TARGET_CONFIG_DIR="$2"
            shift
            ;;
        --backup-existing-config)
            BACKUP_EXISTING=1
            SETUP_ARGS+=(--backup-aux-config)
            ;;
        --no-config-install)
            INSTALL_CONFIG=0
            ;;
        --dry-run)
            DRY_RUN=1
            SETUP_ARGS+=(--dry-run)
            ;;
        --no-extra-runtimes)
            SETUP_ARGS+=(--no-extra-runtimes)
            ;;
        --with-cli-tools)
            SETUP_ARGS+=(--with-cli-tools)
            ;;
        --with-font)
            SETUP_ARGS+=(--with-font)
            ;;
        --with-p10k)
            SETUP_ARGS+=(--with-p10k)
            ;;
        --with-tmux)
            SETUP_ARGS+=(--with-tmux)
            ;;
        --with-zshrc)
            SETUP_ARGS+=(--with-zshrc)
            ;;
        --no-aux-config-install)
            SETUP_ARGS+=(--no-aux-config-install)
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
    shift
done

[[ "$(uname -s)" == "Linux" ]] || die "Linux required"
[[ -f "$SOURCE_CONFIG_DIR/init.lua" ]] || die "missing Neovim config: $SOURCE_CONFIG_DIR"
[[ -x "$SOURCE_CONFIG_DIR/setup.sh" ]] || die "missing executable setup script: $SOURCE_CONFIG_DIR/setup.sh"

if [[ "$INSTALL_CONFIG" -eq 1 && "$DRY_RUN" -eq 0 && "$TARGET_CONFIG_DIR" != "$SOURCE_CONFIG_DIR" ]]; then
    if [[ -e "$TARGET_CONFIG_DIR" || -L "$TARGET_CONFIG_DIR" ]]; then
        if [[ "$BACKUP_EXISTING" -ne 1 ]]; then
            die "config already exists: $TARGET_CONFIG_DIR; use --backup-existing-config or --no-config-install"
        fi

        backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/nvim-setup/backups"
        backup_path="$backup_root/nvim-$(date +%Y%m%d-%H%M%S)-$$"
        mkdir -p "$backup_root"
        mv -- "$TARGET_CONFIG_DIR" "$backup_path"
        printf '[linux-setup] backed up existing config to %s\n' "$backup_path"
    fi

    mkdir -p "$TARGET_CONFIG_DIR"
    for item in init.lua lazy-lock.json lua autoload icons; do
        if [[ -e "$SOURCE_CONFIG_DIR/$item" ]]; then
            cp -a "$SOURCE_CONFIG_DIR/$item" "$TARGET_CONFIG_DIR/"
        fi
    done
fi

if [[ "$INSTALL_CONFIG" -eq 1 && "$DRY_RUN" -eq 1 && "$TARGET_CONFIG_DIR" != "$SOURCE_CONFIG_DIR" ]]; then
    printf '[linux-setup] would install config at %s\n' "$TARGET_CONFIG_DIR"
fi

if [[ "$INSTALL_CONFIG" -eq 1 ]]; then
    NVIM_CONFIG_DIR="$TARGET_CONFIG_DIR" "$SOURCE_CONFIG_DIR/setup.sh" "${SETUP_ARGS[@]}"
else
    NVIM_CONFIG_DIR="$SOURCE_CONFIG_DIR" "$SOURCE_CONFIG_DIR/setup.sh" "${SETUP_ARGS[@]}"
fi
