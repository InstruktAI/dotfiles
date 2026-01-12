# Aliases.

alias _="sudo"
alias watch='watch '

alias vi="vim"
alias rr="rm -rf"

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias -- -="cd -"

# Git shortcuts.
alias g="git"
alias "g?"="git status"
alias "g+"="git add"
alias "g-"="git rm"
alias "g!"="git commit -am"
alias "gf!"="git commit --no-verify -am"
alias gp="git pull"
alias gps="git push"

# Docker shortcuts.
alias dk="docker"
alias dc="docker compose"
alias ds="docker service"
alias dps="docker ps"
alias dpa="docker ps -a"
alias di="docker images"
alias dl="docker ps -l -q"

# eza-powered ls (fallback to ls).
if is_executable eza; then
  alias l="eza -lah --group-directories-first --git"
  alias ll="eza -lAh --group-directories-first --git"
  alias lt="eza -lah --sort=modified --group-directories-first --git"
  alias ld="eza -ld --group-directories-first */"
else
  alias l="ls -lahA"
  alias ll="ls -lA"
  alias lt="ls -lhAtr"
  alias ld="ls -ld */"
fi

if $(is_supported "alias -g"); then
    alias -g G="| grep -i"
    alias -g H="| head"
    alias -g T="| tail"
    alias -g L="| less"
    alias -g P="| pbcopy"
fi

# macOS convenience.
alias killfinder="killall Finder"
alias killdock="killall Dock"
alias killmenubar="killall SystemUIServer NotificationCenter"

# Workspaces
alias cdw="cd ~/Documents/Workspace"
alias cdi="cd ~/Documents/Workspace/InstruktAI"
alias cdm="cd ~/Documents/Workspace/morriz"
alias cds="cd ~/Documents/Workspace/StadsAvonturen"

# Agents
alias cc="claude --dangerously-skip-permissions"
alias cdx="codex --dangerously-bypass-approvals-and-sandbox --search"
alias gg="gemini --yolo"

