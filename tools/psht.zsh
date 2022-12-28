#!/usr/bin/env zsh

# Unset precmd, which (usually) renders the line above the prompt
precmd () true

zle -N psht-next psht_next
zle -N psht-prev psht_previous

bindkey '^[j' psht-next
bindkey '^[k' psht-prev
