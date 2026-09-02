# arch-install/dotfiles/.zshrc
# Arch単独機用の最小構成。Debian機の.zshrcとは無関係（共有しない）。

# --- 基本 ---
export LANG=ja_JP.UTF-8
export EDITOR=vim
export PATH="$HOME/.local/bin:$PATH"

# --- 補完 ---
autoload -Uz compinit && compinit

# --- 履歴 ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups
setopt share_history

# --- プロンプト（シンプル） ---
autoload -Uz vcs_info
precmd() { vcs_info }
setopt prompt_subst
zstyle ':vcs_info:git:*' formats '(%b)'
PROMPT='%F{cyan}%~%f %F{green}${vcs_info_msg_0_}%f
%# '

# --- エイリアス ---
alias ls='ls --color=auto'
alias ll='ls -la'
alias update='sudo pacman -Syu'

# --- syntax highlighting（存在すれば読み込む） ---
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- keychain ---
[ -f "$HOME/.keychain/$HOST-sh" ] && source "$HOME/.keychain/$HOST-sh"
