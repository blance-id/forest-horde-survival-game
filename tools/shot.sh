#!/usr/bin/env bash
# Renders the game under Xvfb and saves a screenshot.
# Usage: tools/shot.sh out.png [frames] [--screen=res://scenes/...] [extra user args]
set -u
OUT="$1"; shift
FRAMES="${1:-90}"; shift || true
mkdir -p "$(dirname "$OUT")"
LOG="$(xvfb-run -a -s "-screen 0 1080x1920x24" timeout 120 godot --audio-driver Dummy --rendering-driver opengl3 --resolution 720x1280 -- --screenshot="$OUT" --after="$FRAMES" --quit "$@" 2>&1)"
echo "$LOG" | grep -vE '^\s+(at:|GDScript backtrace|\[[0-9]+\] )' | grep -vE '^\s*$' | grep -vE 'XDG|xkbcommon|OpenGL API' 
if echo "$LOG" | grep -vE 'resources still in use at exit' | grep -qE 'SCRIPT ERROR|ERROR:'; then echo "### FAILED: errors detected"; exit 1; fi
[ -f "$OUT" ] && echo "### OK -> $OUT" || { echo "### FAILED: no screenshot"; exit 1; }
