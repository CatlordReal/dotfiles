# Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# PATH / environment
export PATH="$HOME/.config/utilities:$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
#export PATH="/.cargo/bin:/opt/homebrew/bin:/user/local/bin:opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/kianconti/.jenv/shims:/Users/kianconti/.jenv/bin:/Library/Java/JavaVirtualMachines/microsoft-11.jdk/Contents/Home/bin:/.config/utilities"
export LDFLAGS="-L/opt/homebrew/Cellar/jpeg/9f/lib"
export CPPFLAGS="-I/opt/homebrew/Cellar/jpeg/9f/include"
export PATH="$PATH:/usr/local/share/dotnet"
export DOTNET_ROOT="/opt/homebrew/opt/dotnet@8/libexec"
export PATH="$DOTNET_ROOT:$PATH"
export PATH="$HOME/.dotnet/tools:$PATH"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/sfml@2/lib"
export CPPFLAGS="-I/opt/homebrew/opt/sfml@2/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/sfml@2/lib/pkgconfig"
export CMAKE_PREFIX_PATH="/opt/homebrew/opt/sfml@2"
export PATH="$HOME/dotfiles/scripts:$PATH"

# Conda
__conda_setup="$('/opt/homebrew/Caskroom/miniforge/base/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/homebrew/Caskroom/miniforge/base/etc/profile.d/conda.sh" ]; then
        . "/opt/homebrew/Caskroom/miniforge/base/etc/profile.d/conda.sh"
    else
        export PATH="/opt/homebrew/Caskroom/miniforge/base/bin:$PATH"
    fi
fi
unset __conda_setup

# Completion + fzf-tab
autoload -U compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
source ~/.fzf-tab/fzf-tab.zsh

# Utilities
. /opt/homebrew/etc/profile.d/z.sh

# Powerlevel10k
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Plugins
source ~/.zsh-autosuggestions/zsh-autosuggestions.zsh
fpath+=(~/.zsh-completions)

# fzf (Homebrew)
source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
source /opt/homebrew/opt/fzf/shell/completion.zsh

# Syntax highlighting must be last
source ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# Must be last
source ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:$(go env GOPATH)/bin"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Homebridge
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"
