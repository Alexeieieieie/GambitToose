# Third-party components

GambitToose uses no third-party images, sprites, music or sound effects. Everything below is the complete list of outside material.

| Component | Used for | Version | License | Source |
|---|---|---|---|---|
| Godot Engine | Game engine and runtime (embedded in the exported .exe) | 3.6.3 | MIT | https://godotengine.org/license |
| Nunito font (Regular 400, Bold 700) | All in-game text, `Game/fonts/Nunito-*.ttf` | 2014 release, static instances cut from the official variable font with fontTools | SIL Open Font License 1.1 (text in `Game/fonts/OFL.txt`) | https://github.com/googlefonts/nunito |

## Own work

- **Graphics**: drawn in code at runtime. No image files besides the project icon `Game/icon.png`, which is our own.
- **Sound and music**: generated offline by `Game/tools/gen_sfx.py` (Python standard library only, fixed seeds) and checked by `Game/tools/check_audio.py`. No samples or sound libraries.
- **Code, levels, tutorial text**: written for this hackathon.

## Development tools (not shipped)


- fontTools, used once to cut the static Nunito weights.

Also listed in `Game/CREDITS.txt`.
