# Linux zsh configuration installed by linux-setup.sh.

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
export DOTNET_ROOT="${DOTNET_ROOT:-$HOME/.dotnet}"

# Persist command history so zsh-autosuggestions has previous commands to match.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=10000
setopt APPEND_HISTORY SHARE_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS HIST_IGNORE_SPACE
autoload -Uz add-zsh-hook
_dotfiles_import_history_once() {
  add-zsh-hook -d precmd _dotfiles_import_history_once
  [[ -r "$HISTFILE" && -z ${_DOTFILES_HISTORY_IMPORTED-} ]] || return
  fc -RI "$HISTFILE"
  typeset -g _DOTFILES_HISTORY_IMPORTED=1
}
add-zsh-hook precmd _dotfiles_import_history_once

# Powerlevel10k instant prompt and theme.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

for p10k_theme in \
  "${XDG_DATA_HOME:-$HOME/.local/share}/powerlevel10k/powerlevel10k.zsh-theme" \
  /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme \
  /usr/share/powerlevel10k/powerlevel10k.zsh-theme; do
  if [[ -r "$p10k_theme" ]]; then
    source "$p10k_theme"
    break
  fi
done
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# Completion.
autoload -U compinit
compinit
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
[[ -n ${LS_COLORS-} ]] && zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# fzf bindings must load before fzf-tab so fzf-tab owns Tab afterwards.
if command -v fzf >/dev/null 2>&1; then
  for fzf_script in \
    "$HOME/.fzf/shell/key-bindings.zsh" \
    /usr/share/fzf/shell/key-bindings.zsh \
    /usr/share/fzf/key-bindings.zsh; do
    if [[ -r "$fzf_script" ]]; then
      source "$fzf_script"
      break
    fi
  done
  for fzf_script in \
    "$HOME/.fzf/shell/completion.zsh" \
    /usr/share/fzf/shell/completion.zsh \
    /usr/share/fzf/completion.zsh; do
    if [[ -r "$fzf_script" ]]; then
      source "$fzf_script"
      break
    fi
  done
fi

# Optional shell plugins: prefer user copies, then distro packages.
for plugin in \
  "$HOME/.fzf-tab/fzf-tab.plugin.zsh" \
  "$HOME/.fzf-tab/fzf-tab.zsh" \
  /usr/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh; do
  if [[ -r "$plugin" ]]; then
    source "$plugin"
    break
  fi
done
for plugin in \
  "$HOME/.zsh-autosuggestions/zsh-autosuggestions.zsh" \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  if [[ -r "$plugin" ]]; then
    source "$plugin"
    break
  fi
done

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Prefer the shared listing configuration; retain aliases on shell-only installs.
if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/shell/listing.zsh" ]]; then
  source "${XDG_CONFIG_HOME:-$HOME/.config}/shell/listing.zsh"
else
  # Icon-aware directory listings (Nerd Font recommended).
  if command -v eza >/dev/null 2>&1; then
    alias ls='eza --grid --across --icons=auto --group-directories-first'
    alias ll='eza --icons=auto --group-directories-first --long --git'
    alias la='eza --grid --across --icons=auto --group-directories-first --all'
    alias lla='eza --icons=auto --group-directories-first --long --git --all'
    alias lt='eza --icons=auto --group-directories-first --tree --level=2'
  fi
fi

# Syntax highlighting must load after other plugins that register ZLE widgets.
for plugin in \
  "$HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  if [[ -r "$plugin" ]]; then
    source "$plugin"
    break
  fi
done
