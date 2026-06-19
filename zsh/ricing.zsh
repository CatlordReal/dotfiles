# Catppuccin ricing shell integrations. This file is sourced from ~/.zshrc.

export BAT_THEME="${BAT_THEME:-Catppuccin Mocha}"
export EZA_ICONS_AUTO=1
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} \
  --height=40% --layout=reverse --border=rounded \
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
  --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
  --color=selected-bg:#45475a"

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza -lah --icons=auto --group-directories-first --git'
  alias la='eza -la --icons=auto --group-directories-first'
  alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi

if command -v lazygit >/dev/null 2>&1; then
  alias lg='lazygit'
fi

if command -v yazi >/dev/null 2>&1; then
  function yy() {
    local tmp
    tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return
    yazi "$@" --cwd-file="$tmp"
    local cwd
    cwd="$(command cat "$tmp" 2>/dev/null)"
    rm -f "$tmp"
    if [[ -n "$cwd" && "$cwd" != "$PWD" ]]; then
      cd "$cwd" || return
    fi
  }
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
