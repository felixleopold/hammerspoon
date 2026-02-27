#!/bin/bash

# Sync fabric patterns from .hammerspoon to .config/fabric
# This allows managing patterns in the dotfiles repo while keeping them available for fabric

SOURCE="$HOME/dotfiles/.hammerspoon/fabric-patterns/"
DEST="$HOME/.config/fabric/patterns/"

echo "Syncing patterns from $SOURCE to $DEST..."
rsync -av "$SOURCE" "$DEST"
echo "Sync complete."
