#!/usr/bin/env bash
# Boots the game headless for N frames (default 180) and fails on any script error.
# Usage: tools/check.sh [frames] [extra godot args...]
set -u
FRAMES="${1:-180}"; shift || true
OUT="$(timeout 120 godot --headless --quit-after "$FRAMES" "$@" 2>&1)"
STATUS=$?
echo "$OUT" | grep -vE '^\s+(at:|GDScript backtrace|\[[0-9]+\] )' | grep -vE '^\s*$'
# "resources still in use at exit" is Godot exit noise: audio playing at quit is
# only released by a mix step that never runs during shutdown.
if echo "$OUT" | grep -vE 'resources still in use at exit' | grep -qE 'SCRIPT ERROR|ERROR:|Parse Error|Invalid call|Nonexistent'; then
  echo "### FAILED: errors detected"; exit 1
fi
echo "### OK (exit $STATUS)"; exit 0
