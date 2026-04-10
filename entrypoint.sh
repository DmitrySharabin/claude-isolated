#!/bin/bash
set -e

# Claude Code stores auth at ~/.claude.json (home root)
# but only ~/.claude/ is mounted as a persistent volume.
# Symlink so the token survives container restarts.
if [ ! -L /home/claude/.claude.json ]; then
    if [ -f /home/claude/.claude/.claude.json ]; then
        ln -sf /home/claude/.claude/.claude.json /home/claude/.claude.json
    else
        touch /home/claude/.claude/.claude.json
        ln -sf /home/claude/.claude/.claude.json /home/claude/.claude.json
    fi
fi

exec claude "$@"
