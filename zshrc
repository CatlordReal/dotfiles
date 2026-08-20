# Linux zsh configuration installed by linux-setup.sh.

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
export DOTNET_ROOT="${DOTNET_ROOT:-$HOME/.dotnet}"

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
zstyle ':completion:*' menu select
zstyle ':completion:*:descriptions' format '[%d]'

# Optional shell plugins installed outside this repository.
for plugin in \
  "$HOME/.fzf-tab/fzf-tab.zsh" \
  "$HOME/.zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "$HOME/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
  [[ -r "$plugin" ]] && source "$plugin"
done

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
  for fzf_script in \
    /usr/share/fzf/shell/key-bindings.zsh \
    /usr/share/fzf/shell/completion.zsh \
    "$HOME/.fzf/shell/key-bindings.zsh" \
    "$HOME/.fzf/shell/completion.zsh"; do
    [[ -r "$fzf_script" ]] && source "$fzf_script"
  done
fi
