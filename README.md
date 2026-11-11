# GridFlow (АвтоТрафик)

2D traffic automation game for Godot 3 (built and tested on 3.6.3, GLES2). The player builds
roads and programs traffic lights and sorters; trucks drive themselves.

- `Game/` is the Godot project. Open `Game/project.godot` in Godot 3.5 or 3.6 and press F5.
- `promts/` holds the build brief. `Game/DECISIONS.md` lists where the game differs from it.

## Controls
Mouse: pick a tool in the bottom bar, click or drag on the map. Click a light or a sorter to
program it. `Space` pause, `1` `2` `3` speed, `H` heatmap, `R` restart, `Esc` menu, `F3` FPS.

## Tests
```
./godot.sh                              # the 11 required headless tests
./godot.sh res://tests/smoke.tscn       # end-to-end run of all three levels
./godot.sh --no-window --quit           # project loads without script errors
```
`godot.sh` uses the Godot binary in `$GODOT`, or `~/Applications/Godot.app` by default.

## After changing assets
```
cd Game && python3 tools/gen_sfx.py     # regenerate the sounds (optional)
./godot.sh --editor --quit              # import pass
```

## Windows build
The preset "Windows Desktop" is in `Game/export_presets.cfg` (single .exe, tests excluded).
1. Install the export templates that match your Godot version (Editor > Manage Export Templates).
2. Run `mkdir -p build && ./godot.sh --no-window --export "Windows Desktop" ../build/GridFlow.exe`,
   or use Project > Export in the editor.
3. Copy `build/GridFlow.exe` to the Windows machine and run it. It needs no network.
