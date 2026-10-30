# KDE Store listing

Texts and settings for the page on https://store.kde.org (copy and paste).

## Where

Add a product in the category **Plasma Wallpaper Plugins** (Plasma 6). Upload the files below as downloads of the
product.

## Downloads

| File | Label | Use |
|---|---|---|
| `Substrate-1.0.0-linux-x86_64.zip` | `Plasma 6 package (x86_64, Qt 6.5 or newer)` | Ready to install: `kpackagetool6 -t Plasma/Wallpaper -i <file>` |
| `Substrate-KDE-Wallpaper-1.0.0.zip` | `Source (build with ./install.sh)` | For every other system: unpack, run `./install.sh` |

Both files are attached to the GitHub release of the tag (`v1.0.0`), made by `tools/make-package.sh` and
`tools/make-zip.sh`. Upload the same files here.

## Name

Substrate

## Summary

Growing cracks, sand, sparks and explosions as a native Plasma 6 wallpaper. No browser needed.

## Description

Substrate grows cracks across your desktop: lines race over the screen, branch off each other at right angles, leave
clouds of sand behind them and throw sparks. It is a port of the Substrate screensaver, written in C++ and Qt Quick.

**Features**

* Fast: the simulation takes about 0.4 ms per step at 1080p, smooth at the refresh rate of your screen
* 54 built-in themes in `bright` and `oled`, each with the variants *no sparks*, *sparks* and *explosions*,
  plus themes in the colors of your Plasma accent color
* Rainbow lines whose colors fade while they grow
* Explosions: a line that hits another one can blow up, erase everything around it and burst into sand and sparks
* A theme manager with inheritance: collections (also nested) hold default values, themes only store what they change
* A theme assistant: answer a few questions, let the rest be rolled, create one or many themes
* Power aware: limit the frame rate or pause on battery, with a locked screen, or while a window covers the desktop
* Several themes at once: tick whole collections and single themes, they take turns

**Installation**

The package contains a compiled plugin, so it works on x86_64 systems with Plasma 6 and Qt 6.5 or newer.
Install it with `kpackagetool6 -t Plasma/Wallpaper -i Substrate-1.0.0-linux-x86_64.zip` (or unzip it into
`~/.local/share/plasma/wallpapers/com.github.spider19996.substrate/`) and restart Plasma:
`systemctl --user restart plasma-plasmashell`. On any other system, or if the package does not load, download the
source and run `./install.sh` (needs cmake, a C++ compiler and the Qt 6 development packages).

Then choose **Substrate** as the wallpaper type.

Source and documentation: https://github.com/Spider19996/Substrate-KDE-Wallpaper

## Tags

plasma6, wallpaper, generative, animated, cracks, substrate, qt6

## License

MIT

## Screenshots

`docs/sparks.jpg`, `docs/rainbow.jpg`, `docs/explosions.jpg`, `docs/bright.jpg`, `docs/theme-manager.jpg`,
`docs/assistant.jpg`

## Changelog (1.0.0)

First release.
