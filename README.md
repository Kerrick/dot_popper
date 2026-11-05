# Dot Popper

Dots bounce around the screen. Tap a fresh dot to pop it, earn a point, and buy a second. Tap a dot you've already popped and it costs you two of each. Keep going until time runs out.

The catch is the stacking order. Popped dots stay on screen and stay on top, and each new fresh dot appears *underneath* all of them. As the round goes on, the popped dots crowd the top layer, and you have to wait for the fresh one to slide out from under them. Tap too soon and you hit a popped dot instead.

Dot Popper is written in Ruby on [Lota](https://github.com/setdef/Lota), which runs Ruby games on a modified build of LÖVE's 2D engine.

## Playing

| | |
| --- | --- |
| Pop a dot | Tap it, or click it with any mouse button. A press counts on the way down. |
| Start, continue | Tap anywhere |
| Sound on or off | The speaker on the title screen, or **M** |
| Fullscreen | **F11**, or **Alt+Enter** (**Cmd+Enter** on a Mac) |
| Quit | **Escape**, or close the window |

A fresh dot is bright and glossy. A popped dot is a muted, matte disc with a dark crater in its centre. The two differ in lightness and shape as well as colour, so they read apart in greyscale and for colour-blind players. The first time you tap a popped dot, a one-line hint under the score explains why, and never again. The game keeps your best score, whether sound is on, and whether you've seen that hint, on the device. When time is up, the dots tumble into a pile behind your score. Set `DOT_POPPER_CALM=1` to turn off the screen shake and let the pile settle softly.

## Installing and running

You need Ruby 4.0.9 (named in `.ruby-version` and `mise.toml`) on macOS 15 or newer on Apple silicon, Windows x64 with [RubyInstaller](https://rubyinstaller.org/), or Linux x86_64. Lota is not on RubyGems.org, so its precompiled gems for those three platforms are in `vendor/cache`, checked against Lota's release checksums in `Gemfile.lock`.

```sh
bundle install
bundle exec lota run
```

To play without Ruby, download a build instead. Every push to `trunk` builds a Windows installer and `.zip`, and a macOS `.dmg`, as artifacts of the [Package workflow](https://github.com/Kerrick/dot_popper/actions/workflows/package.yml). A `v0.*` tag also attaches them to a [release](https://github.com/Kerrick/dot_popper/releases). [PACKAGING.md](PACKAGING.md) explains how the builds are made, and how to build one yourself.

## Development settings

`main.rb` reads these from the environment, for testing and for capturing screenshots:

| Variable | Effect |
| --- | --- |
| `DOT_POPPER_AUTOPLAY=1` | A bot plays: it mostly taps fresh dots and sometimes a popped one, so penalties show |
| `DOT_POPPER_SHOTS=0.5,3,6.5` | Saves screenshots at these game-time seconds as `shot-N.png` in the save folder, and prints each path |
| `DOT_POPPER_QUIT_AFTER=20` | Quits after this many seconds of game time |
| `DOT_POPPER_SEED=42` | Makes the dots' randomness repeatable |
| `DOT_POPPER_NO_SHADERS=1` | Draws without shaders, as the game does on its own when a shader fails to compile |

## Running the tests

```sh
bundle exec rake test
```

`bundle exec rake` runs the tests and then [Steep](https://github.com/soutaro/steep), which checks the rules against their RBS signatures in `sig/`.

The tests need no window. The rules (dots, scoring, the clock, which dot a tap reaches, and the flow from title to game over) live in `lib/dot_popper` and know nothing of Lota. The presentation's own logic, such as easing, effects, input routing, layout, and pixel snapping, lives in `lib/dot_popper/presentation` and is tested the same way. Only `lib/dot_popper/shell` and `main.rb` talk to Lota.

`script/simulate.rb` plays the real rules with a model player at several screen sizes. It's a design tool, not a test, and [doc/decisions.md](doc/decisions.md) explains what it found.

## How the dot's size is chosen

The rules call for a dot whose radius R is a physical size: about 8 mm under a finger, and 50 logical pixels under a mouse, where a logical pixel is a pixel after the system's display scaling. Every other distance and speed in the rules is a multiple of R.

`conf.rb` turns on `t.highdpi`. With that, Lota's graphics units are logical pixels on a desktop (a 2× display draws each one as four physical pixels) and points or dp on a phone or tablet, and Lota reports the scale as `Lota::Graphics.dpi_scale`. What neither Lota nor LÖVE can report is a display's physical density. So `DotPopper::DotSize` computes R once at start from `Lota::System.os`, and makes it 50 units everywhere: 50 logical pixels under a mouse, and on a touch system 50 points or dp, which comes to 7.9 to 9.6 mm on current iPhones and iPads and 7.9 mm by Android's definition. The game prints its choice when it starts.

Because R is fixed, how much fits on the screen is not. The desktop window opens at 24 × 16 R, about the size of an 11-inch iPad in radii, so the game plays alike on both. [doc/decisions.md](doc/decisions.md) has the numbers.

## Where things are

| Path | What it holds |
| --- | --- |
| `lib/dot_popper/rules.rb` | Every rule number: the radius, the speeds, the starting time, the rewards and penalties |
| `lib/dot_popper/presentation/look.rb` | Every presentation setting: the palette, durations, effect strengths, sizes |
| `lib/dot_popper/` | The rules, as small objects, mostly `Data` values |
| `lib/dot_popper/presentation/` | How the game looks, sounds, and responds, without Lota |
| `lib/dot_popper/shell/` | Drawing, sound, saving, and input, with Lota |
| `conf.rb`, `main.rb` | Lota's settings and callbacks |
| `assets/` | The font and shaders |
| `bin/dot_popper`, `fledge.yml` | The launcher and the settings for packaged builds |

## License

Dot Popper is copyright 2026 Kerrick Long and licensed [AGPL-3.0-or-later](LICENSE), like Lota. Its sounds are synthesised in code when the game starts, and its icon is drawn by `script/make_icon.rb`; both are [CC0-1.0](LICENSES/CC0-1.0.txt). The Fredoka font is by the Fredoka Project Authors, under the [SIL Open Font License 1.1](assets/fonts/OFL.txt).

Lota is an independent project. It is not made, endorsed, or supported by the LÖVE Development Team.
