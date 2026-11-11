#!/bin/sh
# Runs the headless tests (or any other Godot arguments) and filters engine noise.
cd "$(dirname "$0")/Game"
G="${GODOT:-/Users/alexei/Applications/Godot.app/Contents/MacOS/Godot}"
if [ $# -eq 0 ]; then set -- --no-window -s tests/run_tests.gd; fi
"$G" --path . "$@" 2>&1 | grep -v -e '^$' -e '^arguments' -e '^[0-9]*: ' -e 'Current path' -e 'UNSUPPORTED' -e '^ $' -e 'OpenGL ES' -e 'Godot Engine v'
