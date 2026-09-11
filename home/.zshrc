# NeKoRoSHELL Zsh configuration

if [[ -r /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme ]]; then
  source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
elif [[ -r "$HOME/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  source "$HOME/powerlevel10k/powerlevel10k.zsh-theme"
fi

[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory sharehistory hist_ignore_dups

bindkey -e
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' forward-word
bindkey '^H' backward-kill-word
bindkey '^[[3;5~' kill-word

if (( $+commands[fzf] )); then
  source <(fzf --zsh)
fi

export PATH="$HOME/.local/bin/nekoroshell:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"
