#!/usr/bin/env bash
set -Eeuo pipefail

MIN_NVIM_VERSION="0.11.0"
MIN_NODE_VERSION="18.0.0"
DOTNET_CHANNEL="10.0"
INSTALL_EXTRA_RUNTIMES="${INSTALL_EXTRA_RUNTIMES:-1}"
DRY_RUN=0
WITH_CLI_TOOLS=0
WITH_FONT=0
WITH_P10K=0
WITH_TMUX=0
INSTALL_AUX_CONFIG=1
BACKUP_AUX_CONFIG=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        --no-extra-runtimes)
            INSTALL_EXTRA_RUNTIMES=0
            ;;
        --with-cli-tools)
            WITH_CLI_TOOLS=1
            WITH_FONT=1
            WITH_P10K=1
            WITH_TMUX=1
            ;;
        --with-font)
            WITH_FONT=1
            ;;
        --with-p10k)
            WITH_P10K=1
            ;;
        --with-tmux)
            WITH_TMUX=1
            ;;
        --no-aux-config-install)
            INSTALL_AUX_CONFIG=0
            ;;
        --backup-aux-config)
            BACKUP_AUX_CONFIG=1
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
    shift
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_DIR="${NVIM_CONFIG_DIR:-$SCRIPT_DIR}"
NVIM_APPNAME="${NVIM_APPNAME:-$(basename "$NVIM_CONFIG_DIR")}"
CONFIG_HOME_PARENT="${XDG_CONFIG_HOME:-$(dirname "$NVIM_CONFIG_DIR")}"
XDG_DATA_HOME_VALUE="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME_VALUE="${XDG_STATE_HOME:-$HOME/.local/state}"

LOCAL_BIN="$HOME/.local/bin"
LOCAL_OPT="$HOME/.local/opt"
DOTNET_ROOT_DIR="$HOME/.dotnet"
STATE_DIR="$XDG_STATE_HOME_VALUE/$NVIM_APPNAME"
HEALTH_LOG="$STATE_DIR/setup-health.log"
MASON_BIN_DIR="$XDG_DATA_HOME_VALUE/$NVIM_APPNAME/mason/bin"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
P10K_SOURCE="$REPO_ROOT/.p10k.zsh"
TMUX_SOURCE="$REPO_ROOT/.tmux.conf"
P10K_DIR="${POWERLEVEL10K_DIR:-$XDG_DATA_HOME_VALUE/powerlevel10k}"
FONT_DIR="${XDG_DATA_HOME_VALUE:-$HOME/.local/share}/fonts/JetBrainsMonoNerdFont"

OS=""
ARCH=""
PACKAGE_MANAGER=""
NVIM_BIN=""

MASON_PACKAGES=(
    clangd
    html-lsp
    lemminx
    lua-language-server
    pyright
    codelldb
    netcoredbg
    stylua
    ruff
    prettier
    roslyn
)

shell_join() {
    local out=()
    local arg
    for arg in "$@"; do
        out+=("$(printf '%q' "$arg")")
    done
    printf '%s' "${out[*]}"
}

log() {
    printf '[nvim-setup] %s\n' "$*"
}

warn() {
    printf '[nvim-setup] warning: %s\n' "$*" >&2
}

die() {
    printf '[nvim-setup] error: %s\n' "$*" >&2
    exit 1
}

run() {
    log "+ $(shell_join "$@")"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        "$@"
    fi
}

run_with_sudo() {
    if [[ "$EUID" -eq 0 ]]; then
        run "$@"
    elif command -v sudo >/dev/null 2>&1; then
        run sudo "$@"
    else
        die "sudo is required to install system packages"
    fi
}

ensure_dir() {
    if [[ ! -d "$1" ]]; then
        run mkdir -p "$1"
    fi
}

have() {
    command -v "$1" >/dev/null 2>&1
}

strip_v() {
    printf '%s' "${1#v}"
}

version_ge() {
    local left right i l r
    IFS='.' read -r -a left <<<"$(strip_v "$1")"
    IFS='.' read -r -a right <<<"$(strip_v "$2")"
    for i in 0 1 2 3; do
        l="${left[i]:-0}"
        r="${right[i]:-0}"
        if (( 10#$l > 10#$r )); then
            return 0
        fi
        if (( 10#$l < 10#$r )); then
            return 1
        fi
    done
    return 0
}

version_lt() {
    ! version_ge "$1" "$2"
}

current_nvim_version() {
    "$1" --version 2>/dev/null | awk 'NR==1 { sub(/^v/, "", $2); print $2; exit }' || true
}

current_node_version() {
    node -v 2>/dev/null | tr -d 'v'
}

current_dotnet_version() {
    dotnet --version 2>/dev/null | head -n1
}

set_platform() {
    [[ "$(uname -s)" == "Linux" ]] || die "Linux required"
    OS="linux"

    case "$(uname -m)" in
        x86_64|amd64)
            ARCH="x64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            die "unsupported architecture: $(uname -m)"
            ;;
    esac
}

prepend_runtime_path() {
    case ":$PATH:" in
        *":$DOTNET_ROOT_DIR:"*) ;;
        *) export PATH="$DOTNET_ROOT_DIR:$PATH" ;;
    esac
    case ":$PATH:" in
        *":$LOCAL_BIN:"*) ;;
        *) export PATH="$LOCAL_BIN:$PATH" ;;
    esac
    export DOTNET_ROOT="$DOTNET_ROOT_DIR"
}

selected_shell_profile() {
    local shell_name
    shell_name="${SHELL##*/}"
    case "$shell_name" in
        zsh)
            printf '%s' "$HOME/.zprofile"
            ;;
        bash)
            printf '%s' "$HOME/.bash_profile"
            ;;
        *)
            printf '%s' "$HOME/.profile"
            ;;
    esac
}

ensure_shell_exports() {
    local profile begin end
    profile="$(selected_shell_profile)"
    begin="# >>> nvim-setup >>>"
    end="# <<< nvim-setup <<<"

    if [[ -f "$profile" ]] && grep -Fq "$begin" "$profile"; then
        return
    fi

    ensure_dir "$(dirname "$profile")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would append PATH exports to $profile"
        return
    fi

    {
        printf '\n%s\n' "$begin"
        printf 'export PATH="$HOME/.local/bin:$HOME/.dotnet:$PATH"\n'
        printf 'export DOTNET_ROOT="$HOME/.dotnet"\n'
        printf '%s\n' "$end"
    } >> "$profile"
}

detect_linux_package_manager() {
    local candidate
    for candidate in apt-get dnf yum pacman zypper; do
        if have "$candidate"; then
            PACKAGE_MANAGER="$candidate"
            return
        fi
    done
    die "unsupported Linux package manager; expected apt-get, dnf, yum, pacman, or zypper"
}

linux_refresh_repos() {
    case "$PACKAGE_MANAGER" in
        apt-get)
            run_with_sudo apt-get update
            ;;
        dnf)
            run_with_sudo dnf makecache
            ;;
        yum)
            run_with_sudo yum makecache
            ;;
        pacman)
            run_with_sudo pacman -Sy --noconfirm
            ;;
        zypper)
            run_with_sudo zypper --gpg-auto-import-keys refresh
            ;;
    esac
}

linux_install_packages() {
    case "$PACKAGE_MANAGER" in
        apt-get)
            run_with_sudo apt-get install -y "$@"
            ;;
        dnf)
            run_with_sudo dnf install -y "$@"
            ;;
        yum)
            run_with_sudo yum install -y "$@"
            ;;
        pacman)
            run_with_sudo pacman -S --needed --noconfirm "$@"
            ;;
        zypper)
            run_with_sudo zypper --non-interactive install "$@"
            ;;
    esac
}

linux_try_install() {
    local mode="$1"
    shift
    local attempt
    local -a packages

    for attempt in "$@"; do
        IFS=' ' read -r -a packages <<<"$attempt"
        if linux_install_packages "${packages[@]}"; then
            return 0
        fi
    done

    if [[ "$mode" == required ]]; then
        die "failed to install required Linux packages: $*"
    fi
    warn "skipping optional Linux packages: $*"
    return 0
}

install_linux_logical() {
    local logical="$1"
    local mode="$2"

    case "$PACKAGE_MANAGER:$logical" in
        apt-get:core-utils)
            linux_try_install "$mode" "ca-certificates curl git unzip tar gzip xz-utils"
            ;;
        apt-get:build)
            linux_try_install "$mode" "build-essential pkg-config"
            ;;
        apt-get:rg)
            linux_try_install "$mode" "ripgrep"
            ;;
        apt-get:fd)
            linux_try_install "$mode" "fd-find"
            ;;
        apt-get:sqlite)
            linux_try_install "$mode" "sqlite3 libsqlite3-dev"
            ;;
        apt-get:xml)
            linux_try_install "$mode" "libxml2-utils"
            ;;
        apt-get:xdg)
            linux_try_install "$mode" "xdg-utils"
            ;;
        apt-get:python)
            linux_try_install "$mode" "python3 python3-pip python3-pytest"
            ;;
        apt-get:node)
            linux_try_install "$mode" "nodejs npm"
            ;;
        apt-get:lua)
            linux_try_install "$mode" "lua5.1 luarocks" "lua5.4 luarocks"
            ;;
        apt-get:lazygit)
            linux_try_install "$mode" "lazygit"
            ;;
        apt-get:gh)
            linux_try_install "$mode" "gh"
            ;;
        apt-get:rust)
            linux_try_install "$mode" "rustc cargo"
            ;;
        apt-get:java)
            linux_try_install "$mode" "default-jdk" "openjdk-21-jdk"
            ;;
        apt-get:tmux)
            linux_try_install "$mode" "tmux"
            ;;
        apt-get:shell)
            linux_try_install "$mode" "zsh fontconfig"
            ;;

        dnf:core-utils|yum:core-utils)
            linux_try_install "$mode" "ca-certificates curl git unzip tar gzip xz"
            ;;
        dnf:build|yum:build)
            linux_try_install "$mode" "make gcc gcc-c++ pkgconf-pkg-config"
            ;;
        dnf:rg|yum:rg)
            linux_try_install "$mode" "ripgrep"
            ;;
        dnf:fd|yum:fd)
            linux_try_install "$mode" "fd-find" "fd"
            ;;
        dnf:sqlite|yum:sqlite)
            linux_try_install "$mode" "sqlite sqlite-devel"
            ;;
        dnf:xml|yum:xml)
            linux_try_install "$mode" "libxml2"
            ;;
        dnf:xdg|yum:xdg)
            linux_try_install "$mode" "xdg-utils"
            ;;
        dnf:python|yum:python)
            linux_try_install "$mode" "python3 python3-pip python3-pytest"
            ;;
        dnf:node|yum:node)
            linux_try_install "$mode" "nodejs npm"
            ;;
        dnf:lua|yum:lua)
            linux_try_install "$mode" "lua luarocks"
            ;;
        dnf:lazygit|yum:lazygit)
            linux_try_install "$mode" "lazygit"
            ;;
        dnf:gh|yum:gh)
            linux_try_install "$mode" "gh" "github-cli"
            ;;
        dnf:rust|yum:rust)
            linux_try_install "$mode" "rust cargo"
            ;;
        dnf:java|yum:java)
            linux_try_install "$mode" "java-latest-openjdk-devel" "java-21-openjdk-devel"
            ;;
        dnf:tmux|yum:tmux)
            linux_try_install "$mode" "tmux"
            ;;
        dnf:shell|yum:shell)
            linux_try_install "$mode" "zsh fontconfig"
            ;;

        pacman:core-utils)
            linux_try_install "$mode" "ca-certificates curl git unzip tar gzip xz"
            ;;
        pacman:build)
            linux_try_install "$mode" "base-devel pkgconf"
            ;;
        pacman:rg)
            linux_try_install "$mode" "ripgrep"
            ;;
        pacman:fd)
            linux_try_install "$mode" "fd"
            ;;
        pacman:sqlite)
            linux_try_install "$mode" "sqlite"
            ;;
        pacman:xml)
            linux_try_install "$mode" "libxml2"
            ;;
        pacman:xdg)
            linux_try_install "$mode" "xdg-utils"
            ;;
        pacman:python)
            linux_try_install "$mode" "python python-pip python-pytest"
            ;;
        pacman:node)
            linux_try_install "$mode" "nodejs npm"
            ;;
        pacman:lua)
            linux_try_install "$mode" "lua luarocks"
            ;;
        pacman:lazygit)
            linux_try_install "$mode" "lazygit"
            ;;
        pacman:gh)
            linux_try_install "$mode" "github-cli"
            ;;
        pacman:rust)
            linux_try_install "$mode" "rust"
            ;;
        pacman:java)
            linux_try_install "$mode" "jdk-openjdk"
            ;;
        pacman:tmux)
            linux_try_install "$mode" "tmux"
            ;;
        pacman:shell)
            linux_try_install "$mode" "zsh fontconfig"
            ;;

        zypper:core-utils)
            linux_try_install "$mode" "ca-certificates curl git unzip tar gzip xz"
            ;;
        zypper:build)
            linux_try_install "$mode" "make gcc gcc-c++ pkg-config"
            ;;
        zypper:rg)
            linux_try_install "$mode" "ripgrep"
            ;;
        zypper:fd)
            linux_try_install "$mode" "fd"
            ;;
        zypper:sqlite)
            linux_try_install "$mode" "sqlite3 sqlite3-devel"
            ;;
        zypper:xml)
            linux_try_install "$mode" "libxml2-tools" "libxml2"
            ;;
        zypper:xdg)
            linux_try_install "$mode" "xdg-utils"
            ;;
        zypper:python)
            linux_try_install "$mode" "python3 python3-pip python3-pytest"
            ;;
        zypper:node)
            linux_try_install "$mode" "nodejs npm" "nodejs20 npm20" "nodejs18 npm18"
            ;;
        zypper:lua)
            linux_try_install "$mode" "lua51 luarocks" "lua54 luarocks" "lua luarocks"
            ;;
        zypper:lazygit)
            linux_try_install "$mode" "lazygit"
            ;;
        zypper:gh)
            linux_try_install "$mode" "gh" "github-cli"
            ;;
        zypper:rust)
            linux_try_install "$mode" "rust cargo"
            ;;
        zypper:java)
            linux_try_install "$mode" "java-latest-openjdk-devel" "java-21-openjdk-devel"
            ;;
        zypper:tmux)
            linux_try_install "$mode" "tmux"
            ;;
        zypper:shell)
            linux_try_install "$mode" "zsh fontconfig"
            ;;

        *)
            die "unsupported Linux install target: $PACKAGE_MANAGER:$logical"
            ;;
    esac
}

install_linux_packages() {
    detect_linux_package_manager
    linux_refresh_repos

    install_linux_logical core-utils required
    install_linux_logical build required
    install_linux_logical rg required
    install_linux_logical fd required
    install_linux_logical sqlite required
    install_linux_logical xml required
    install_linux_logical xdg required
    install_linux_logical python required
    install_linux_logical node required
    install_linux_logical lua required

    if [[ "$INSTALL_EXTRA_RUNTIMES" -eq 1 ]]; then
        install_linux_logical lazygit optional
        install_linux_logical gh optional
        install_linux_logical rust optional
        install_linux_logical java optional
    fi
}

install_linux_cli_tools() {
    local -a package_attempts
    case "$PACKAGE_MANAGER" in
        apt-get)
            package_attempts=("bat" "eza" "fzf" "zoxide" "git-delta" "starship" "yazi" "tmux" "btop" "jq" "wget" "htop" "ncdu" "tree")
            ;;
        dnf)
            package_attempts=("bat" "eza" "fzf" "zoxide" "git-delta" "starship" "yazi" "tmux" "btop" "jq" "wget" "htop" "ncdu" "tree")
            ;;
        yum)
            package_attempts=("bat bat-extras" "eza" "fzf" "zoxide" "git-delta delta" "starship" "yazi" "tmux" "btop" "jq" "wget" "htop" "ncdu" "tree")
            ;;
        pacman)
            package_attempts=("bat" "eza" "fzf" "zoxide" "git-delta" "starship" "yazi" "tmux" "btop" "jq" "wget" "htop" "ncdu" "tree")
            ;;
        zypper)
            package_attempts=("bat" "eza" "fzf" "zoxide" "git-delta delta" "starship" "yazi" "tmux" "btop" "jq" "wget" "htop" "ncdu" "tree")
            ;;
        *)
            die "unsupported Linux package manager for CLI tools: $PACKAGE_MANAGER"
            ;;
    esac

    local attempts
    local -a attempts_array
    for attempts in "${package_attempts[@]}"; do
        read -r -a attempts_array <<<"$attempts"
        linux_try_install optional "${attempts_array[@]}"
    done
}

ensure_symlink_alias() {
    local alias_name="$1"
    local target_cmd="$2"
    local target_path

    if have "$alias_name" || ! have "$target_cmd"; then
        return
    fi

    ensure_dir "$LOCAL_BIN"
    target_path="$(command -v "$target_cmd")"
    run ln -sf "$target_path" "$LOCAL_BIN/$alias_name"
}

ensure_common_aliases() {
    ensure_symlink_alias fd fdfind
    ensure_symlink_alias bat batcat
    ensure_symlink_alias node nodejs

    if ! have lua; then
        local candidate
        for candidate in lua5.1 lua5.4 lua54 lua51; do
            if have "$candidate"; then
                ensure_symlink_alias lua "$candidate"
                break
            fi
        done
    fi
}

backup_aux_target() {
    local target="$1" backup_root backup_path
    backup_root="${XDG_STATE_HOME_VALUE:-$HOME/.local/state}/nvim-setup/backups"
    backup_path="$backup_root/aux-$(date +%Y%m%d-%H%M%S)-$(basename "$target")-$$"
    ensure_dir "$backup_root"
    run mv -- "$target" "$backup_path"
    log "backed up existing auxiliary config to $backup_path"
}

install_aux_config() {
    local source="$1" target="$2"
    [[ -f "$source" ]] || { warn "optional config source missing: $source"; return; }

    if [[ -e "$target" || -L "$target" ]]; then
        if [[ "$BACKUP_AUX_CONFIG" -eq 1 ]]; then
            backup_aux_target "$target"
        else
            warn "preserving existing auxiliary config: $target"
            return
        fi
    fi

    ensure_dir "$(dirname "$target")"
    run cp -a "$source" "$target"
    log "installed auxiliary config: $target"
}

install_jetbrains_mono_nerd_font() {
    local tmp_dir archive_file font_file
    if have fc-list && fc-list | grep -Fqi 'JetBrainsMono Nerd Font'; then
        log "JetBrainsMono Nerd Font already installed"
        return
    fi

    ensure_dir "$FONT_DIR"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would install JetBrainsMono Nerd Font to $FONT_DIR"
        return
    fi

    tmp_dir="$(mktemp -d)"
    archive_file="$tmp_dir/JetBrainsMono.zip"
    run curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip -o "$archive_file"
    run unzip -oq "$archive_file" -d "$tmp_dir/fonts"
    while IFS= read -r -d '' font_file; do
        run cp -f "$font_file" "$FONT_DIR/"
    done < <(find "$tmp_dir/fonts" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)
    if have fc-cache; then
        run fc-cache -f "$FONT_DIR"
    fi
    log "installed JetBrainsMono Nerd Font"
}

install_powerlevel10k() {
    if [[ -d "$P10K_DIR/.git" ]]; then
        log "Powerlevel10k already installed at $P10K_DIR"
    elif [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would clone Powerlevel10k to $P10K_DIR"
    else
        ensure_dir "$(dirname "$P10K_DIR")"
        run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    fi

    if [[ "$INSTALL_AUX_CONFIG" -eq 1 ]]; then
        install_aux_config "$P10K_SOURCE" "$HOME/.p10k.zsh"
    fi
    log "Powerlevel10k ready; source ~/.p10k.zsh from your zsh startup file"
}

install_tmux_config() {
    if [[ "$INSTALL_AUX_CONFIG" -eq 1 ]]; then
        install_aux_config "$TMUX_SOURCE" "$HOME/.tmux.conf"
    fi
}

install_auxiliary_tools() {
    if [[ "$WITH_FONT" -eq 1 ]]; then
        install_jetbrains_mono_nerd_font
    fi
    if [[ "$WITH_P10K" -eq 1 ]]; then
        install_powerlevel10k
    fi
    if [[ "$WITH_TMUX" -eq 1 ]]; then
        install_tmux_config
    fi
}

install_node_locally() {
    local tmp_dir archive_url version archive_file extracted_dir target_dir tarball_name
    ensure_dir "$LOCAL_BIN"
    ensure_dir "$LOCAL_OPT"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would install Node.js LTS for $OS/$ARCH"
        return
    fi

    readarray -t node_release < <(python3 - "$OS" "$ARCH" <<'PY'
import json
import sys
import urllib.request

os_name, arch = sys.argv[1:3]
platform = "linux"
ext = ".tar.xz"
release_index = json.load(urllib.request.urlopen("https://nodejs.org/dist/index.json"))
for release in release_index:
    if not release.get("lts"):
        continue
    version = release["version"]
    asset = f"node-{version}-{platform}-{arch}{ext}"
    print(version)
    print(f"https://nodejs.org/dist/{version}/{asset}")
    break
else:
    raise SystemExit("no Node.js LTS release found")
PY
)

    version="${node_release[0]}"
    archive_url="${node_release[1]}"
    tarball_name="${archive_url##*/}"
    target_dir="$LOCAL_OPT/node-${version#v}"

    if [[ -x "$target_dir/bin/node" ]]; then
        log "Node.js LTS already unpacked at $target_dir"
    else
        tmp_dir="$(mktemp -d)"
        archive_file="$tmp_dir/$tarball_name"
        run curl -fsSL "$archive_url" -o "$archive_file"
        run tar -xf "$archive_file" -C "$tmp_dir"
        extracted_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d -name 'node-*' | head -n1)"
        [[ -n "$extracted_dir" ]] || die "failed to unpack Node.js archive"
        if [[ -d "$target_dir" ]]; then
            run rm -rf "$target_dir"
        fi
        run mv "$extracted_dir" "$target_dir"
    fi

    run ln -sf "$target_dir/bin/node" "$LOCAL_BIN/node"
    run ln -sf "$target_dir/bin/npm" "$LOCAL_BIN/npm"
    run ln -sf "$target_dir/bin/npx" "$LOCAL_BIN/npx"
    if [[ -x "$target_dir/bin/corepack" ]]; then
        run ln -sf "$target_dir/bin/corepack" "$LOCAL_BIN/corepack"
    fi
}

ensure_node_runtime() {
    local node_version
    if have node; then
        node_version="$(current_node_version || true)"
        if [[ -n "$node_version" ]] && version_ge "$node_version" "$MIN_NODE_VERSION"; then
            log "Node.js $node_version satisfies the minimum version"
            return
        fi
        warn "Node.js ${node_version:-unknown} is older than $MIN_NODE_VERSION; installing a local LTS copy"
    else
        warn "Node.js not found; installing a local LTS copy"
    fi

    install_node_locally
}

ensure_npm_prefix() {
    ensure_dir "$LOCAL_BIN"
    run npm config set prefix "$HOME/.local"
}

ensure_npm_tools() {
    ensure_npm_prefix
    run npm install --global typescript ts-node
}

install_neovim_locally() {
    local tmp_dir archive_url version archive_file extracted_dir target_dir asset_name
    ensure_dir "$LOCAL_BIN"
    ensure_dir "$LOCAL_OPT"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        NVIM_BIN="$LOCAL_BIN/nvim"
        log "Would install latest Neovim for $OS/$ARCH"
        return
    fi

    readarray -t nvim_release < <(python3 - "$OS" "$ARCH" <<'PY'
import json
import sys
import urllib.request

os_name, arch = sys.argv[1:3]
asset_names = {
        ("linux", "x64"): "nvim-linux-x86_64.tar.gz",
        ("linux", "arm64"): "nvim-linux-arm64.tar.gz",
    }
want = asset_names[(os_name, arch)]
release = json.load(urllib.request.urlopen("https://api.github.com/repos/neovim/neovim/releases/latest"))
for asset in release["assets"]:
    if asset["name"] == want:
        print(release["tag_name"].lstrip("v"))
        print(asset["browser_download_url"])
        break
else:
    raise SystemExit(f"missing Neovim asset: {want}")
PY
)

    version="${nvim_release[0]}"
    archive_url="${nvim_release[1]}"
    asset_name="${archive_url##*/}"
    target_dir="$LOCAL_OPT/nvim-$version"

    if [[ -x "$target_dir/bin/nvim" ]]; then
        log "Neovim $version already unpacked at $target_dir"
    else
        tmp_dir="$(mktemp -d)"
        archive_file="$tmp_dir/$asset_name"
        run curl -fsSL "$archive_url" -o "$archive_file"
        run tar -xf "$archive_file" -C "$tmp_dir"
        extracted_dir="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d -name 'nvim-*' | head -n1)"
        [[ -n "$extracted_dir" ]] || die "failed to unpack Neovim archive"
        if [[ -d "$target_dir" ]]; then
            run rm -rf "$target_dir"
        fi
        run mv "$extracted_dir" "$target_dir"
    fi

    run ln -sf "$target_dir/bin/nvim" "$LOCAL_BIN/nvim"
    NVIM_BIN="$LOCAL_BIN/nvim"
}

resolve_nvim() {
    prepend_runtime_path

    if have nvim; then
        local version
        NVIM_BIN="$(command -v nvim)"
        version="$(current_nvim_version "$NVIM_BIN")"
        if [[ -n "$version" ]] && version_ge "$version" "$MIN_NVIM_VERSION"; then
            log "Using Neovim $version at $NVIM_BIN"
            return
        fi
        warn "Neovim ${version:-unknown} is older than $MIN_NVIM_VERSION; installing a local copy"
    elif [[ -x "$LOCAL_BIN/nvim" ]]; then
        local version
        NVIM_BIN="$LOCAL_BIN/nvim"
        version="$(current_nvim_version "$NVIM_BIN")"
        if [[ -n "$version" ]] && version_ge "$version" "$MIN_NVIM_VERSION"; then
            log "Using Neovim $version at $NVIM_BIN"
            return
        fi
    fi

    install_neovim_locally
    ensure_shell_exports
}

ensure_dotnet_sdk() {
    prepend_runtime_path

    if have dotnet; then
        local version
        version="$(current_dotnet_version || true)"
        if [[ -n "$version" ]] && ! version_lt "$version" "$DOTNET_CHANNEL.0"; then
            log ".NET SDK $version is already installed"
            return
        fi
        warn ".NET SDK ${version:-unknown} is older than $DOTNET_CHANNEL; installing a local SDK"
    else
        warn ".NET SDK not found; installing a local SDK"
    fi

    ensure_dir "$DOTNET_ROOT_DIR"
    ensure_dir "$LOCAL_BIN"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would install .NET SDK $DOTNET_CHANNEL"
        ensure_shell_exports
        return
    fi

    local tmp_dir installer
    tmp_dir="$(mktemp -d)"
    installer="$tmp_dir/dotnet-install.sh"
    run curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer"
    run bash "$installer" --channel "$DOTNET_CHANNEL" --install-dir "$DOTNET_ROOT_DIR" --no-path
    run ln -sf "$DOTNET_ROOT_DIR/dotnet" "$LOCAL_BIN/dotnet"
    ensure_shell_exports
}

ensure_dotnet_tools() {
    ensure_dir "$LOCAL_BIN"

    if [[ -x "$LOCAL_BIN/easydotnet" ]]; then
        run dotnet tool update --tool-path "$LOCAL_BIN" EasyDotnet
    else
        run dotnet tool install --tool-path "$LOCAL_BIN" EasyDotnet
    fi
}

require_command() {
    local cmd="$1"
    local label="$2"
    if ! have "$cmd"; then
        die "$label is required but was not found in PATH"
    fi
}

run_nvim_headless() {
    prepend_runtime_path
    run env \
        "PATH=$PATH" \
        "DOTNET_ROOT=$DOTNET_ROOT_DIR" \
        "XDG_CONFIG_HOME=$CONFIG_HOME_PARENT" \
        "NVIM_APPNAME=$NVIM_APPNAME" \
        "$NVIM_BIN" --headless "$@"
}

install_lazy_plugins() {
    run_nvim_headless "+Lazy! restore" "+TSUpdateSync" "+qa"
}

install_mason_packages() {
    local package_line
    package_line="${MASON_PACKAGES[*]}"
    run_nvim_headless "+MasonUpdate" "+MasonInstall $package_line" "+qa"
}

write_health_log() {
    ensure_dir "$STATE_DIR"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would write Neovim health output to $HEALTH_LOG"
        return
    fi

    if ! env \
        "PATH=$PATH" \
        "DOTNET_ROOT=$DOTNET_ROOT_DIR" \
        "XDG_CONFIG_HOME=$CONFIG_HOME_PARENT" \
        "NVIM_APPNAME=$NVIM_APPNAME" \
        "$NVIM_BIN" --headless "+checkhealth" "+qa" >"$HEALTH_LOG" 2>&1; then
        warn "checkhealth reported issues; see $HEALTH_LOG"
    fi
}

verify_post_install() {
    require_command git git
    require_command curl curl
    require_command tar tar
    require_command gzip gzip
    require_command unzip unzip
    require_command make make
    require_command python3 python3
    require_command node node
    require_command npm npm
    require_command rg ripgrep
    require_command fd fd
    require_command sqlite3 sqlite3
    require_command xmllint xmllint
    require_command lua lua
    require_command dotnet dotnet
    require_command easydotnet easydotnet
    require_command ts-node ts-node
    require_command pytest pytest
    require_command "$NVIM_BIN" neovim

    local mason_required=(
        "$MASON_BIN_DIR/clangd"
        "$MASON_BIN_DIR/lemminx"
        "$MASON_BIN_DIR/lua-language-server"
        "$MASON_BIN_DIR/pyright-langserver"
        "$MASON_BIN_DIR/vscode-html-language-server"
        "$MASON_BIN_DIR/stylua"
        "$MASON_BIN_DIR/ruff"
        "$MASON_BIN_DIR/prettier"
        "$MASON_BIN_DIR/codelldb"
        "$MASON_BIN_DIR/netcoredbg"
        "$MASON_BIN_DIR/roslyn"
    )
    local path
    for path in "${mason_required[@]}"; do
        [[ -x "$path" ]] || die "required Mason binary is missing: $path"
    done
}

main() {
    set_platform
    ensure_dir "$LOCAL_BIN"
    ensure_dir "$LOCAL_OPT"
    prepend_runtime_path

    install_linux_packages
    if [[ "$WITH_CLI_TOOLS" -eq 1 ]]; then
        install_linux_cli_tools
    fi
    if [[ "$WITH_TMUX" -eq 1 && "$WITH_CLI_TOOLS" -eq 0 ]]; then
        install_linux_logical tmux optional
    fi
    if [[ "$WITH_FONT" -eq 1 || "$WITH_P10K" -eq 1 ]]; then
        install_linux_logical shell optional
    fi

    ensure_common_aliases
    install_auxiliary_tools
    ensure_node_runtime
    ensure_npm_tools
    resolve_nvim
    ensure_dotnet_sdk
    ensure_dotnet_tools

    require_command python3 python3
    require_command curl curl
    require_command tar tar
    require_command gzip gzip

    install_lazy_plugins
    install_mason_packages

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Dry run complete"
        return
    fi

    verify_post_install
    write_health_log

    log "Setup complete"
    log "Neovim: $NVIM_BIN"
    log "Health log: $HEALTH_LOG"
}

main "$@"
