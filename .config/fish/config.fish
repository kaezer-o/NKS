# NeKoRoSHELL fish configuration, based on the current Caelestia terminal
# workflow. No Oh-My-Zsh or Powerlevel10k dependency is required here.

if status is-interactive
    # Caelestia-style prompt.
    if type -q starship
        starship init fish | source
    end

    # Directory/environment helpers used by the Caelestia fish setup.
    if type -q direnv
        direnv hook fish | source
    end
    if type -q zoxide
        zoxide init fish --cmd cd | source
    end

    # Better ls when eza is available.
    if type -q eza
        alias ls='eza --icons --group-directories-first -1'
    end

    # Git abbreviations from the Caelestia fish configuration.
    abbr lg 'lazygit'
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'
    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'

    # Keep terminal prompt marks compatible with Caelestia/foot integrations.
    function mark_prompt_start --on-event fish_prompt
        echo -en '\e]133;A\e\\'
    end

    # Preserve NKS command discovery.
    fish_add_path "$HOME/.local/bin/nekoroshell" "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/go/bin"
end
