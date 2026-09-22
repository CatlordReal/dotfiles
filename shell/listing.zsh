# Icon-aware directory listings (Nerd Font recommended).
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons=auto --group-directories-first'
  alias ll='eza --icons=auto --group-directories-first --long --git'
  alias la='eza --icons=auto --group-directories-first --all'
  alias lla='eza --icons=auto --group-directories-first --long --git --all'
  alias lt='eza --icons=auto --group-directories-first --tree --level=2'
fi
