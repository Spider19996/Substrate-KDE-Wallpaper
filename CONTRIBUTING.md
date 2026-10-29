# Contributing

Thanks for wanting to help! Bug reports, themes and pull requests are all welcome.

## Reporting a problem

Please open an issue and tell us:

- your Plasma and Qt versions (`plasmashell --version`, `qmake6 -query QT_VERSION`) and whether you use Wayland or X11,
- what you did and what you expected,
- for performance problems: the output of `SUBSTRATE_DEBUG=1 plasmashell --replace` (frame timing statistics are printed
  to stderr every five seconds), or a run of the benchmark described in the README.

## Building

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DSUBSTRATE_BUILD_BENCH=ON
cmake --build build
python3 tests/check_themes.py
```

Without installing anything you can try the QML module by pointing `QML_IMPORT_PATH` at `build/qml`.
Plasma loads a plugin only once per run, so restart it after installing a new build:
`systemctl --user restart plasma-plasmashell`.

## Code

- `src/substrateengine.*` holds the simulation and must stay free of Qt Quick code, so it can be benchmarked headless.
- Keep the simulation cheap: it runs on the GUI thread, once per step.
- User-facing strings are English and go through `i18n()` in QML.
- Match the style of the surrounding code and keep comments short; explain the why, not the what.

## Themes

Built-in themes live in `contents/themes/<collection>/<name>.json`. A collection folder may contain
`_collection.json` with defaults that all themes and subcollections inherit; a theme file only needs the values that
differ. `python3 tests/check_themes.py` checks that the files are valid and only use known settings.

## Versions

The version lives in `VERSION` of the top-level `CMakeLists.txt` (shown on the settings page) and in
`metadata.json`. Keep both in step; releases are tagged `v<version>` on GitHub.

`./tools/make-zip.sh` packs what a build and an installation need into `dist/Substrate-KDE-Wallpaper-<version>.zip`
(for the KDE Store or for sharing). Pushing a tag does the same on GitHub and attaches the zip to the release
(`.github/workflows/release.yml`).

## Pull requests

Describe what changed and why, and say how you tested it. Small, focused changes are easier to review.
