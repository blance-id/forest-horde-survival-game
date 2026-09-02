#!/usr/bin/env bash
# Runs the headless unit tests. Exit code = number of failures.
cd "$(dirname "$0")/.." || exit 1
timeout 300 godot --headless --audio-driver Dummy -s tests/run_tests.gd 2>&1 | grep -vE '^\s+(at:|GDScript backtrace|\[[0-9]+\] )' | grep -vE '^\s*$'
exit "${PIPESTATUS[0]}"
