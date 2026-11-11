# GridFlow

2D traffic automation game for Godot 3 (built and tested on 3.6.3, GLES2). The player builds
roads and programs traffic lights and sorters; trucks drive themselves.

- `Game/` is the Godot project. Open `Game/project.godot` in Godot 3.5 or 3.6 and press F5.
- `promts/` holds the build brief. `Game/DECISIONS.md` lists where the game differs from it.

## First launch and the tutorial
On a fresh install the game opens a Welcome screen, then runs an interactive tutorial (6 short lessons
and a final test), then shows a completion screen and the main menu. The next launch goes straight to the
menu. The tutorial can be skipped (with a confirmation) and replayed any time from the main menu; replaying
never changes saved progress or best scores.

What is remembered lives in `user://save.cfg` (tutorial done, language, sound, best scores). It is never part
of the project or the export. To test the first-run flow again, run the game from the editor (a debug build)
and press **F9**: it deletes the save and returns to the Welcome screen. Or delete `save.cfg` by hand
(Project > Open User Data Folder).

Tutorial code lives in `Game/tutorial/` (`tutorial_data.gd` has every lesson and step, `tutorial_manager.gd`
runs them without any scene nodes). The game is in English by default; Russian is an option on the main menu.
All text is in `Game/autoload/strings.gd` (`EN` and `RU` tables, `Strings.t("KEY")`).

## Controls
Mouse: pick a tool in the bottom bar, click or drag on the map. Click a light or a sorter to
program it. `Space` pause, `1` `2` `3` speed, `H` heatmap, `R` retry, `Esc` menu, `F1` help, `F3` FPS.

## Tests
```
./godot.sh                              # the 11 required headless tests
./godot.sh res://tests/smoke.tscn       # end-to-end run of all three levels
./godot.sh --no-window --quit           # project loads without script errors
```
`godot.sh` uses the Godot binary in `$GODOT`, or `~/Applications/Godot.app` by default.

## After changing assets
```
cd Game && python3 tools/gen_sfx.py     # regenerate the sounds (optional, standard library only)
./godot.sh --editor --quit              # import pass
```

## Windows build
The preset "Windows Desktop" is in `Game/export_presets.cfg` (single .exe, tests excluded).
1. Install the export templates that match your Godot version (Editor > Manage Export Templates).
2. Run `mkdir -p build && ./godot.sh --no-window --export "Windows Desktop" ../build/GridFlow.exe`,
   or use Project > Export in the editor.
3. Copy `build/GridFlow.exe` to the Windows machine and run it. It needs no network.
