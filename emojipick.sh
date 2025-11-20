#!/bin/bash

# --- Configuration ---
EMOJI_FILE="$HOME/.emojis"
# Choose your picker: 'dmenu' or 'fzf'
PICKER="fzf"
# --- End Configuration ---

# Function to run the picker based on selection
run_picker() {
    if [ "$PICKER" = "dmenu" ]; then
        # -l 10: 10 lines, -i: case insensitive, -p: prompt
        dmenu -l 10 -i -p 'Emoji:'
    elif [ "$PICKER" = "fzf" ]; then
        # --height=10: 10 lines high, --reverse: show from top
        fzf --height=10 --reverse --layout=reverse --border
    else
        echo "Error: PICKER must be 'dmenu' or 'fzf'" >&2
        exit 1
    fi
}

# 1. Read the list of emojis and descriptions.
# 2. Pipe the list to the selected picker.
# 3. Use 'awk' to extract the emoji and 'printf' (instead of print) to suppress the newline.
# 4. Pipe the result to 'xclip -selection clipboard' (or -i) to copy to the system clipboard.

cat "$EMOJI_FILE" | \
    run_picker | \
    awk '{printf "%s", $1}' | \
    xclip -i
