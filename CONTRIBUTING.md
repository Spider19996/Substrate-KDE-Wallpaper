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

A build copies the plugin to `contents/ui/lib`, where the QML files load it from (`import "lib"`), so the QML in the
source tree works as is. The folder is generated and not committed.
Plasma loads a plugin only once per run, so restart it after installing a new build:
`systemctl --user restart plasma-plasmashell`.

## Code

- `src/substrateengine.*` holds the simulation and must stay free of Qt Quick code, so it can be benchmarked headless.
- Keep the simulation cheap: it runs on the GUI thread, once per step.
- User-facing strings are English and go through `i18nd("plasma_wallpaper_com.github.spider19996.substrate", …)` in QML (the domain is spelled out,
  so the settings page finds the texts no matter how Plasma sets up its context). Texts that live in a `.js` file
  are wrapped in `N_()` and passed through `i18nd()` where they are shown.
- Translations are `po/<language>.po`. After changing texts run `tools/update-translations.sh`, which refreshes
  `po/substrate.pot` and merges new texts into every `.po`. `tools/build-translations.sh` (run by `install.sh` and
  the packaging script) compiles them into `contents/locale`, which is not committed. To add a language, copy
  `po/substrate.pot` to `po/<language>.po` and translate it.
- Match the style of the surrounding code and keep comments short; explain the why, not the what.

## Themes

Built-in themes live in `contents/themes/<collection>/<name>.json`. A collection folder may contain
`_collection.json` with defaults that all themes and subcollections inherit; a theme file only needs the values that
differ. `python3 tests/check_themes.py` checks that the files are valid and only use known settings.

## Versions

The version lives in `VERSION` of the top-level `CMakeLists.txt` (shown on the settings page) and in
`metadata.json`. Keep both in step; releases are tagged `v<version>` on GitHub.

A release has the finished wallpaper package. `./tools/make-package.sh` builds and packs it
(`dist/Substrate-<version>-linux-<arch>.zip`). The plugin inside only runs with the Qt version it was built against or
a newer one, so releases are built on Qt 6.5. GitHub adds the "Source code" archives itself.

Pushing a tag builds the package on GitHub, checks that it loads on Debian, Fedora and Arch (`tests/package-smoke`)
and attaches it to the release (`.github/workflows/release.yml`).

To try a package on other distributions yourself, run `./tools/test-package.sh [zip]`. It starts podman containers
(Debian 13 and testing, Fedora, Arch) and checks that the plugin of the package loads with their Qt.
`docs/kde-store.md` has the texts for the KDE Store page.

## Pull requests

Describe what changed and why, and say how you tested it. Small, focused changes are easier to review.
