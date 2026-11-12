<!--
  SPDX-FileCopyrightText: 2026 setdef
  SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
-->
# How the game looks and sounds

How Dot Popper draws its dots, its night and its effects, how the Game Over pile behaves, how the game sounds and buzzes, and how themes change all of that. It is for anyone changing `Presentation::Style`, a painter in `lib/dot_popper/shell/`, a shader, or a theme. Every setting named here lives in `Style` (`lib/dot_popper/presentation/style.rb`), in radii (R) and seconds unless it says otherwise. None of it changes the rules: the game's rules are in [rules.md](rules.md), and the tutorial's drawing in [tutorial.md](tutorial.md).

## Bright and popped dots

The ordinary theme's picture is "gumdrops at night" (`Presentation::Palette`, `Style::PALETTE`): bright dots are light, warm and glossy on a deep indigo night; popped dots are dark, matte, opaque discs with a light rim and a sunken crater. The game's icon shows that picture.

The two kinds differ in lightness and in shape, not only in hue, so every player can tell them apart, in grayscale and with color blindness too. In the ordinary palette a bright dot's body (`fresh_body`) is 5.4:1 against a popped dot's top (`popped_top`) and 9.9:1 against the night (`ink_top`).

A bonus dot is a bright dot in mint, as light as any bright dot and marked by a dark four-pointed star, a shape, so it reads without color too. Mint is the color of gain. When it appears and how it pays are in [rules.md](rules.md).

### The bright dot's edge is its hit circle

What is seen of a dot at rest ends exactly at radius R, where its hit circle ends (`Style::DOT`, a `Presentation::DotStyle`):

| Setting | Value | What it is |
| --- | --- | --- |
| `rim` | 0.055 R | A bright dot's cream rim (`fresh_rim`), its outer edge the hit circle, smoothed over one device pixel; never under a pixel and a half wide (`assets/shaders/dot.glsl`). |
| `halo_width`, `halo_alpha` | 0.035 R, 16% | A faint lip just outside a bright dot. It has faded to nothing by 1.15 R (`DotStyle#halo`). |
| `shadow_reach`, `shadow_offset`, `shadow_alpha` | 1.08 R, dropped 0.07 R, 40% | Every dot's shadow, so the dot on top shows. Its lowest edge is within 1.16 R (`DotStyle#shadow_edge`). |
| `extent` | 1.25 R | The half side of the square a shader draws a dot in, room for the halo, the shadow and a mistake's glow. |

A popped dot's opaque body ends at R too. A bright dot at rest is drawn at exactly scale 1: it never swells or breathes. Only the spawn, a pop and a mistake scale a dot briefly (`Style::MOTION`: it grows from 0.15 to 1 in 0.42 s as it spawns; a popped dot stretches from 1.3 back to 1 in 0.6 s; a mistake's wobble is 0.13 at 11 Hz for 0.38 s).

A player aims at a moving target by its edge and tracks it by what they perceive as its boundary, so the visible edge must be the clickable edge (Fitts's law, via Lidwell, Holden and Butler, *Universal Principles of Design*; Johnson, *Designing with the Mind in Mind*; Hodent, *The Gamer's Brain*). Clarity comes before polish (Swink, *Game Feel*). The maintainer asked for it after a soft glow made the clickable area hard to track. Fill, gloss and rim keep the bright dot the brightest thing on screen without anything outside R.

### Drawing order

`Shell::DotPainter` draws the stack bottom first, so the oldest dot is drawn last, on top. Each dot is drawn with its own shadow and halo in that same order, so a popped dot covers the halo of a bright dot beneath it, and a covered bright dot gives nothing away. A pose only scales a dot about its rule position: a dot is always drawn where the rules say it is.

### The tests that hold them

- `test/presentation/color_test.rb` (the ordinary palette): every bright color at least 2.5:1 against every popped color, `fresh_body` at least 4.5:1 against `popped_top` and 3:1 against `popped_lip`, a bright dot at least 7:1 against the night, a popped dot's rim at least 3:1 against it, every color words use at least 4.5:1 on the night, and the bonus dot as light as a bright one, with its star at least 7:1 on its body.
- `test/presentation/theme_test.rb` holds every theme to the same, and more (see "Themes").
- `test/presentation/style_test.rb`: `test_a_dot_at_rest_ends_at_its_hit_circle` (the rim, halo, shadow and extent limits above) and `test_nothing_blooms_around_the_fresh_dot`.
- `test/presentation/dot_animations_test.rb`: a bright dot at rest is drawn at exactly its size.

## Shaders are optional

The game compiles five shaders at start (`Shell::Pen::SHADERS`, in `assets/shaders/`): `dot` (dots), `edge` (the edge glow), `backdrop` (the ordinary night), `blur` (the bloom pass) and `scene` (a theme's sky). A theme's dot shader, in `assets/shaders/themes/`, is compiled the first time the theme is used (`Pen#theme_shader`).

Every shader is optional. One that fails to compile on the player's graphics driver is left out with one warning, and its part is drawn with plain shapes instead (`Pen#compile`); `DOT_POPPER_NO_SHADERS=1` leaves them all out. Shader compilers differ between drivers, and a driver that rejects a shader shouldn't stop anyone from playing.

| Without | What is drawn |
| --- | --- |
| `dot` | Plain circles (`DotPainter#flat`): a bright dot is its rim as a full disc with the body inside it, so its edge is still the hit circle (the rim at least 2 device pixels), with a highlight; a popped dot is a dark disc with a rim and a crater. The shadow is the dot's own disc dropped 0.07 R, a crescent below. |
| A theme's dot shader | The ordinary `dot` shader, in the theme's colors. |
| `backdrop` | The night as 16 bands from `ink_top` to `ink_bottom` (`Renderer#flat_backdrop`). |
| `scene` | The ordinary night, with no scenery (`Shell::Scene#bake`). |
| `blur` | No bloom. |
| Particle sprites | No droplets (`Shell::Sparks#refresh`). |

A Box2D world that cannot be made leaves the dots where they are at Game Over. Sound and haptics that fail are skipped likewise, each with one warning, and play goes on.

## The night

Behind everything is the night: the `backdrop` shader in the palette's four inks, or a theme's baked scene (see "Themes"). It reaches a unit past Lota's dimensions (`Renderer#cover`), and every frame is cleared first to the night's darkest ink, `ink_edge` (`Renderer#prepare`), so a pixel nothing draws is never black or another color. Lota's dimensions are whole units, rounded down, while the drawable may be a fraction of a unit wider: on an iPhone 13 mini turned landscape it is 2338 pixels at a scale of 2.88, 811.8 units, which Lota reports as 811.

The game prints one line on what its window is as it starts and on every resize or rotation (`Presentation::ScreenReport`, `App#report_screen`): its size in units and pixels, the dpi scale as Lota reports it and natively, the safe area and the window's mode. It lets a run on a real device be set beside an SDL test program's on the same one. `DOT_POPPER_DIAGNOSTIC_COLORS=1` clears each frame to pure blue and draws no night ([ios.md](../ios.md)).

## Effects

`Presentation::Effects` keeps what follows a tap; `Shell::EffectsPainter` draws it.

**A pop** (`Show#popped`): a burst of 14 droplets (`POP_BURST`, see "Particles") from the tap, a cream shockwave ring from 1 R to 1.9 R in 0.36 s (`SHOCKWAVE`), the new dot's ripple (`SPAWN_RIPPLE`), and "+1" and "+1s" floating up beside each other (`GAIN_FLOAT`, `FLOAT_SPREAD`). A bonus dot's pop adds a larger burst and a second, wider shockwave (`BONUS_BURST`, `BONUS_SHOCKWAVE`); a bonus dot appears in a wide mint ripple and pulses a ring every 0.9 s while it waits (`BONUS_RIPPLE`, `BONUS_BEACON`). Every ring is an outline, so it hides no dot.

**A mistake** (`Show#penalized`): the tapped dot wobbles and its rim flashes the alarm's pink (`ALARM_RING`); if a bright dot was hidden under it, its dashed outline shows (`REVEAL`, see [tutorial.md](tutorial.md), "The mistake's dashed outline"); the HUD shakes a little, by whole device pixels (`PENALTY_SHAKE`; the dots never shake, since a tap is judged where a dot really is); the screen's edges glow pink, peaking at 42%, a tenth of the screen's shorter side deep, for 0.32 s (`PENALTY_FLASH`, `assets/shaders/edge.glsl`); and the loss floats up (`LOSS_FLOAT`). Where the score's floor kept a number from falling, only what was lost is shown. The glow is narrow and quick so dots near an edge are tinted only for a moment.

**A tap on empty space** in a game shows only a faint ring (`TOUCH_RIPPLE`), a whisper that the tap was heard. **The clock's last 3 seconds** give each tick a faint edge glow (`TICK_FLASH`, `HUD.urgent_below`).

The HUD's pill is 40% opaque (`HUD.backing`), so a dot under it still shows, and its numbers are outlined so they read over a bright dot. The HUD and the screens' layout are in [screens.md](screens.md).

## The bloom pass

`Shell::Bloom` can lay a soft glow under the dots: it draws the bright dots and the droplets into a canvas at the screen's full resolution, blurs it each way at half resolution (`BLOOM.resolution`) with a Gaussian blur (`assets/shaders/blur.glsl`, nine taps folded into five reads by `Presentation::BlurKernel`), and adds the result to the night before any dot is drawn. Drawn underneath, it leaves every dot exactly as sharp, and popped dots over a bright dot hide its glow as they hide the dot. No text is drawn into it.

It is off: `BLOOM.strength` is 0. Any bloom strong enough to see spreads several pixels past R and blurs the bright dot's edge, where the player aims; one tight enough to stay inside the rim adds nothing. Its code stays, and a strength of 0.7 turns it back on. It is also off without the `blur` shader or a canvas. `test/presentation/bloom_test.rb` checks the blur neither brightens nor darkens and only the blurred layer is smaller than the screen.

## Particles

Droplets and twinkles are LÖVE's `ParticleSystem`s (`Shell::Sparks`). A `Presentation::Burst` says everything about a burst: how many, how fast, how long each lives, how big, the air's drag, gravity, opacity, spin and its sprite. `Presentation::Emission` turns it into a particle system's settings in graphics units for the dots' radius.

- **Sprites.** Two, drawn in code at the screen's density, each `PARTICLE_SPRITE`, 24 units, across (`Presentation::SpriteArt`): a soft round droplet, and a twinkle with four thin rays so its spin shows.
- **Systems.** A system runs all its particles through the same colors over their lifetime, so there is one system for each burst and color, made when first needed and reused, with room for four bursts at once. A burst's droplets are shared evenly among its colors (`Burst#shares`).
- **Limits.** A droplet lives at most `Burst::LONGEST_LIFE`, 0.45 s, so a burst never hides the dots around it for long; it shrinks to 0.45 of its size as it goes and fades from its burst's opacity. A pop's droplets live 0.25 to 0.42 s at 80%. Game Over's sparkles may outlive that, at most 1.4 s (`GAME_OVER.sparkle_life`), since no game is behind them: three bursts of 60 spinning twinkles for a new record, and 22 for a met daily goal.
- Droplets are drawn additively, so they only brighten (`EffectsPainter#droplets`).

`test/presentation/particles_test.rb` checks the lifetimes, units, sizes, fades and sprites.

## The Game Over pile

When a game ends its rules are frozen and its dots are only scenery. `Shell::Pile` hands each dot to a `Lota::Physics::World` (LÖVE's binding of Box2D) as a ball of radius R, where it was and going as it went (`PileStyle#launch`, times `fling`). The world has walls at the window's floor and sides, which rise as far again above the window, so the top is open and a dot thrown up comes back down (`Presentation::PileWalls`). The dots fall behind Game Over's dimmed words. Starting a game or returning Home throws the world away. Nothing the pile does can touch a score: the game is over.

The pile is a toy. Schell's lens of the toy (*The Art of Game Design*) asks whether something is fun to play with even with no goal, and a toy is found by playing with it (Sicart, *Play Matters*), so Game Over says nothing about it.

**Scale.** Box2D works best with objects about a meter across, so a Box2D meter is `PILE.meter`, 2 R, which makes a dot a ball one meter across. Gravity is 20 R a second squared. Each physics step covers at most 1/30 s (`longest_step`), so a slow frame cannot tunnel a dot through a wall. A resized window moves the walls and brings back inside any ball the new walls would leave out (`Pile#refit`).

| Setting | `PILE` | `CALM_PILE` (`DOT_POPPER_CALM=1`) |
| --- | --- | --- |
| `gravity` (R/s²) | 20 | 8 |
| `restitution` | 0.35 | 0 (no bounce) |
| `friction` | 0.4 | 0.8 |
| `damping` | 0.05 | 2.5 |
| `fling` (of each dot's last velocity) | 1.0 | 0.25 |

**Tilt and shake** (`Presentation::Tilt`, `Shell::Tilting`, `Shell::Accelerometer`). On a phone or tablet, tilting turns the pile's gravity toward the lowest side of the screen. With a gamepad, the right stick turns it: the dots fall the way it points, at full gravity, and straight down when it is let go; a pushed stick wins over the accelerometer. The accelerometer is on only while the pile exists. Once the pile is tilted or dragged, a lid along the window's top keeps the dots on screen. With neither an accelerometer nor a pushed stick, the pile just falls.

- SDL reports the accelerometer in the device's own portrait axes, as the push holding it up, and never turns those axes with the screen, so `Pull.from_device` maps each of the four display orientations itself. One g is the pile's own gravity, so a device held upright drops the dots as before.
- The reading is smoothed with a time constant of 0.2 s (`TILT.smoothing`), so a hand's tremor never reaches the dots. Sleeping balls are woken when the pull has moved more than 0.05 g.
- A jolt is the reading's change from its own 0.3 s average of more than 1 g; a shake is a jolt followed within 0.35 s by one the opposite way, as a hand shakes, so a single bump such as a footstep never counts. The next shake counts after 0.6 s.
- A shake throws every ball against the pull at least 20 R a second, plus 40 for each g past the threshold, at most 108 (`TiltStyle#kick_for`), each ball at 0.6 to all of that (`Throw`), so the gentlest toss is twice a dot's fastest speed. It makes no sound and no flash: the dots flying is the whole answer.
- Calm (`CALM_TILT`): the pull follows four times as slowly (0.8 s) and a shake never throws.
- `DOT_POPPER_FAKE_TILT=x,y` stands in for an accelerometer in testing.

**Drag and throw** (`Presentation::PileGrabs`, `Shell::Dragging`, `Style::GRAB`). A press on a ball that wanders more than a quarter of a radius, or stays down 0.15 s, picks it up; a quicker, stiller press is a click. How presses become grabs and clicks, per finger, mouse and gamepad, is in [input.md](input.md). A held ball is given each frame the velocity that closes on the pointer in about 0.05 s, at most 60 R a second (Lota binds `MouseJoint.new` but none of its setters, so a joint can't follow a pointer); Box2D's contacts and walls still stop it, and a held ball is a Box2D bullet so it can't pass through a wall. Let go, it flies at the pointer's speed over its last tenth of a second, at most 40 R a second. Calm (`CALM_GRAB`): it closes in 0.12 s, at most 20 R a second, and is thrown at most 6. Dragging closes the lid.

**Game Over's lesson** replays a mistake on the pile at the pile's depth; see [tutorial.md](tutorial.md), "Game Over replays the mistake on the pile".

`test/presentation/pile_test.rb`, `tilt_test.rb` and `pile_grab_test.rb` test all of this without a window; `test/gui/scenarios/pile.rb` and `pile_gamepad.rb` play it. The autoplay bot waits 3.2 s at Game Over (`AUTOPILOT.game_over_wait`) so its screenshots show the pile settled.

## Sound

There are no sound files. Every sound is synthesized when the game starts from `Style::PATCHES` (`Presentation::Synth`, mono, from `Note`s of sine, triangle, square or noise): `pop` (a bubbly bloop), `bonus` (a bell's three notes up), `bonus_pop`, `bonk` (a low, dull fall), `tick` (a woodblock), `start` (three notes up), `game_over` (three notes down) and `new_score_record` (an arpeggio). `Shell::Speaker` plays each with four voices, so quick taps overlap rather than cut each other off, at `SOUND.volume`, 0.8. A pop's pitch climbs 0.02 for each point of the score, up to 1.4; the last seconds' ticks climb 0.12 a second.

**How high a pop goes.** The climb plays the pop's samples faster (OpenAL's pitch), so every frequency in it rises together, by up to 1.4, nearly six semitones: plainly a rise, and it tells a player the game is going well. It reaches the top at 20 points, a few seconds into a good game, so the top of the climb is what a player hears most. A theme's pop is therefore judged at the top of the climb, not where it starts. Every pop, at every point of the climb, stays in the band the ordinary pop and the four Halloween pops keep, measured on the synthesizer's output without its noise (noise has no pitch, and is the sound's texture rather than where it sits):

| Measure | Band | The five reference pops |
| --- | --- | --- |
| Fundamental, the lowest partial with a fifth of the loudest's energy | 170 to 800 Hz | 172 to 791 Hz |
| Centroid, where the tone's energy sits, at the top | at most 1,050 Hz | at most 1,013 Hz |
| The tone's energy over 1.5 kHz, at the top | at most 2% | at most 0.3% |

Above that band the pop moves into 2 to 5 kHz, where the ear is most sensitive (Lee, Wickens, Liu & Boyle, *Designing for People*: hearing has measured limits, so design within them), so the same sound at the same level is heard as louder and sharper, and repeated hundreds of times in a game it grates. A pop is feedback that is heard on every tap, and it should never be more than the moment needs (Saffer, *Microinteractions*). The first holiday pops were bells and chimes pitched at 2 to 3.5 kHz, five to seven times the ordinary pop, and climbed to nearly 5 kHz, or carried a bright ding or arpeggio over a low body; each keeps its intervals, moved down (three semitones to two octaves and more) so all of it sits in the band. `test/presentation/pop_pitch_test.rb` renders every theme's pop and fails if any leaves the band, so a new theme is checked by numbers as well as by ears (Schell, *The Art of Game Design*: the player hears the experience, not the patch, so test what is heard). A mistake's `bonk` never climbs, so the higher the pop goes, the further it is from the mistake.

**Stereo placement.** Every sound is mono, so OpenAL can place it. A pop and a mistake are placed where the tap was across the screen (`Presentation::Stereo#pan`), never more than 60% to one side (`SOUND.stereo`), so both ears hear every sound. `Stereo.position` puts the source on a circle one unit from the listener, at the angle of its pan, so its distance and loudness never change. Every other sound plays from the center. Sound placed where the eye is looking helps a player connect it to its cause. `test/presentation/stereo_test.rb` checks the pan and the distance.

**Mute.** M mutes; so does Settings' Sound ([screens.md](screens.md)). `sound.txt` remembers it (`muted` or `on`), so a player who mutes need not mute again. With no audio device, the game plays nothing and goes on.

## Haptics

On a pop the phone buzzes 15 ms, and on a mistake 40 ms (`Style::HAPTICS`; 0 turns either off), so a player feels the difference as they hear it. A bonus dot's pop adds two more of the mistake's length. `Shell::Haptics` calls `Lota::System.vibrate`, and only on Android (`BUZZING_SYSTEMS`); every other system gets `Presentation::NoHaptics`, which does nothing. LÖVE can vibrate only on iOS and Android, and on iOS it ignores the length and plays the system's long vibration, which would run every pop into the next; iPads have no vibration motor. A short tap on iOS would need `UIImpactFeedbackGenerator`, which neither LÖVE nor Lota exposes. Android's host starts each buzz on a thread of its own ([PACKAGING.md](../../PACKAGING.md)). The tutorial's guide never buzzes ([tutorial.md](tutorial.md)).

## Themes

A theme is a set of art and sound for the whole game. Thirteen ship in `Style::THEMES`: the ordinary one, Classic, first, and twelve with art. A theme changes how the game looks and sounds, never how it plays: gameplay, scores, speeds and touch targets are untouched, hit areas and bounces stay circles, and no theme makes the game easier or harder (Schell's elemental tetrad: aesthetics changes, mechanics do not).

| Theme | Key | File | Dot | Night | Title |
| --- | --- | --- | --- | --- | --- |
| Classic | `:classic` | `Style::PALETTE` | `dot.glsl`: gumdrops | `backdrop.glsl` | Fredoka, candy lettering |
| Ghost | `:ghost` | `themes/ghost.rb` | `ghost.glsl`: a little ghost, white and glowing, gone near black when popped | A foggy graveyard (`:graveyard`) | Fredoka, its O's the theme's bright dots |
| Jack-o'-lantern | `:jack_o_lantern` | `themes/jack_o_lantern.rb` | `jack_o_lantern.glsl`: a carved pumpkin lit by a flickering candle, unlit when popped, every one with the same face | Dusk (`:dusk`) | Creepster, O's as dots |
| Awake | `:awake` | `themes/awake.rb` | `awake.glsl`: an open cat's eye, a shut lid when popped | A dark wood (`:wood`) | Anton, O's as dots |
| Eclipse | `:eclipse` | `themes/eclipse.rb` | `eclipse.glsl`: a harvest moon, in eclipse when popped, so a bright dot sliding out from under a popped one is a crescent | A churchyard (`:churchyard`) | IM Fell Double Pica, beside a small crescent |
| Ornament | `:ornament` | `themes/ornament.rb` | `ornament.glsl`: a mirrored gold glass ornament with a frosted band, reflecting a window and the tree's lights, its crimped cap inside the circle; when popped, the same ornament in dark red glass, broken, a shard gone so the hollow shows, its band, cap and cracks all in dark tones, every one broken alike | Inside a Christmas tree: crisp fir boughs at two depths, strung with dim lights and far ornaments, over a warm glow, and presents on the floor (`:boughs`) | Fredoka, O's as dots |
| Santa | `:santa` | `themes/santa.rb` | `santa.glsl`: Santa's face filling the circle, red hat with fur trim and pompom, rosy cheeks, white beard, brows raised, eyes twinkling over a laughing smile; the same Santa asleep in the dark when popped, all in dark tones, eyes shut, mouth open in a snore | Snowy rooftops on Christmas Eve, lit windows, chimneys, and the sleigh going over (`:rooftops`) | Fredoka, O's as dots |
| Snowman | `:snowman` | `themes/snowman.rb` | `snowman.glsl`: a snowman's face, a packed snowball filling the circle, a striped knit hat, round coal eyes and a broad coal smile, a carrot nose; when popped, the same snowman melted into a dark puddle, all in dark tones, his carrot and coal lying in it and his knit hat beside them, whole, its stripes as on his head | A snowy yard at night: drifts, firs, a cottage, a picket fence and a lamp post (`:snowfield`) | Fredoka, O's as dots |
| Peppermint | `:peppermint` | `themes/peppermint.rb` | `peppermint.glsl`: a glossy starlight mint seen from above, red wedges swirled like a pinwheel and widening out to its edge, round a white star in the middle; when popped, the same mint crunched, in shadow, cracked through into three pieces, its stripes deep red, every one cracked alike | A parlor by firelight: striped paper and a wreath, the mantel with a garland, candles and a nutcracker, stockings with candy canes, and the fire below (`:mantel`) | Fredoka, O's as dots |
| Jingle bell | `:jingle_bell` | `themes/jingle_bell.rb` | `jingle_bell.glsl`: a polished silver jingle bell, its seam, its slot and sound hole, a red ribbon bow at its crown; when popped, the same bell in shadow, burst open along its slot into a wide dark mouth with its little ball inside, every one burst alike | A sleigh ride at twilight: snowy hills at three depths, firs, a split-rail fence, and a one-horse open sleigh with its lantern (`:sleigh_ride`) | Fredoka, O's as dots |
| Gingerbread | `:gingerbread` | `themes/gingerbread.rb` | `gingerbread.glsl`: a round gingerbread cookie, baked golden, a white icing squiggle inside its rim, and an iced gingerbread man on it with red candy buttons; when popped, the same cookie in shadow and the gingerbread man run away, only his man-shaped hole left, every one alike | A kitchen on a snowy night: a window onto the snow with a garland over it, cupboards, and on the counter a gingerbread house, a cookie jar, a rolling pin, and a gingerbread man running off (`:kitchen`) | Fredoka, O's as dots |
| Pumpkin pie | `:pumpkin_pie` | `themes/pumpkin_pie.rb` | `pumpkin_pie.glsl`: a pumpkin pie seen from above in its dish, a crimped crust browned on its crests, glossy custard, a piped swirl of whipped cream; when popped, the same dish after dinner in the dark with the pie gone, its fluted rim, its floor wiped clean but for a trail of crumbs, all in dark tones, every one alike | A farm at dusk on Thanksgiving: far hills and a tree line, the farmhouse with its windows lit and smoke from the chimney, a barn and silo, and near, a tall oak with its last leaves, pumpkins, a split-rail fence and geese going over (`:farm`) | Fredoka, O's as dots |
| Turkey | `:turkey` | `themes/turkey.rb` | `turkey.glsl`: a tom turkey face on in full display, his fan to the circle's edge in rust, orange and gold feathers, each with a dark band and a cream tip, his barred wings dropped, a round bronze breast, a pale blue head and red wattle; when popped, the same tom asleep on his roost at night, all in dark tones: his fan folded shut like a closed hand fan and hanging behind the limb, his wings folded, his head sunk into his shoulders, his eyes shut, every one alike | The edge of a wood at nightfall: a far tree line, a field with round hay bales and a rail fence, and two great oaks with turkeys roosting in their limbs (`:roost`) | Fredoka, O's as dots |

Each theme's dot is one object, and its popped dot is the same object after the pop, in its own terms: unlit, gone dark, eclipsed, shut, broken, asleep, melted, crunched, burst, run away, eaten, gone to roost. That gives the popped dot a shape of its own to learn as well as its darkness, so a sliver of a bright dot is told from it by shape and lightness at a glance (Hodent, *The Gamer's Brain*: players see what they expect, so the cue must be simple and consistent), and the pop means something in the theme's story without changing a rule (Schell's elemental tetrad: the aesthetics support the mechanics). A theme's object may have its own outline only close to the circle, as Ghost's hem is; its hit area and bounce stay the circle.

The theme files are in `lib/dot_popper/presentation/themes/`, their dot shaders in `assets/shaders/themes/`, and the title fonts' licenses in [assets/fonts/README.md](../../assets/fonts/README.md). Theme names are in `Style::WORDS.themes`.

### A theme is one file and one shader

Each theme is a module with one method, `theme(base, hex)`, that returns a `Presentation::Theme`: its `key` (what is saved, and what the server names), its `palette` (the ordinary palette `with` its own colors), its `art` (a `ThemeArt`: the dot shader's name, its sky as a `ThemeSky` for `scene.glsl`, its scenery's kind, its title font and whether the title's O's are dots, and the sound patches it plays instead of the ordinary ones, `pop` and `bonk` in all of them, and `bonus` and `bonus_pop` in Peppermint), and its `opens_on` date. A bonus dot's pop plays the pop and then `bonus_pop` over it; the ordinary `bonus_pop` is the ordinary pop with a chord, so a theme with art plays the chord alone (`Style::THEMED_PATCHES`, `Theme#sounds`) unless it has a `bonus_pop` of its own, and the ordinary pop is never heard under a theme's own. Replacing one theme touches nothing else.

When a theme is used, everything takes it: every dot, the night, buttons, words, effects and the tutorial come from the palette in use (`Pen#palette`); the rings and flashes `Style` colors from the ordinary palette are mapped to the palette in use by their job (`Pen#themed`); the shaders are given its colors (`Pen#paint_shaders`); its dot shader is made ready; the title is set by `Shell::ThemedTitle`; and `Speaker#use` swaps in its sounds. The theme in use is settled when the game starts, when Home shows, and when the player chooses one, never in a game, so a purchase or midnight never repaints a game (`ThemeKeeper#refresh`, `App#use_theme`).

### Scenery is drawn once

A theme's night is baked once for the screen's size into a canvas at the screen's own resolution and drawn 1:1 each frame, so scenery costs one quad on an old phone (`Shell::Scene`): its sky by `scene.glsl`, its silhouettes (trees, hills, a crooked house, a fence, graves, bats, the wood's trunks, fir boughs, presents, rooftops and a sleigh, a snowy yard, a mantel and its fire, a sleigh ride, a kitchen, a farmhouse, barn and oak, and oaks with turkeys roosting in them) as plain filled polygons from `Presentation::Scenery`, then fog by the shader over them where the sky has any. It is baked again whenever the theme or the window changes (`Renderer#prepare`). Without the `scene` shader, or if a canvas can't be made, the ordinary night is drawn.

### Contrast

Every theme keeps a bright dot told from a popped one by shape and lightness, not hue (Hodent; Westland and Maggio, *Universal Principles of Color*). Every popped dot looks like every other popped dot: no color, pattern or shape is chosen per dot, so the eye learns one popped look and passes over it, and only bright dots may each be their own. A dot shader learns which dot it draws only from its `seed`, which `DotStyle#seed` gives each bright dot by its id and every popped dot the same; no dot shader may read where on the screen it draws. `test/presentation/theme_test.rb` holds every theme's palette to these:

| Rule | At least |
| --- | --- |
| Every bright color against every popped color | 2.5:1 |
| `fresh_body` against `popped_top`; against `popped_lip` | 4.5:1; 3:1 |
| `fresh_body` lighter than `popped_rim`, in luminance | 0.15 |
| `fresh_body` against the night (`ink_top`) | 7:1 |
| `popped_rim` against the night, and `popped_top` lighter than it | 3:1 |
| `popped_rim` against `fresh_rim`, so a bright dot under a popped one keeps its edge and the stack's order shows | 2.5:1 |
| `fresh_rim` against `popped_top`; `popped_lip` against `popped_crater` | 4.5:1; 2.2:1 |
| The alarm against `popped_top` | 2.8:1 |
| Every color words use against `ink_bottom` | 4.5:1 |
| Colors that differ between any two themes | 10 |

It also checks that Classic comes first and is the only theme without art, that every theme has a name, that every popped dot gets the same seed while each bright dot gets its own, and that no dot shader reads where on the screen it draws.

### The server unlocks them

A theme other than Classic exists to the player only once the server has named it (`Presentation::ThemeKeeper`). Until then no screen shows a trace of it: no placeholder, no teaser, no count. People do not miss what was never promised (Johnson), and an offer you can see and not have is pressure (Rigby and Ryan, *Glued to Games*).

- `Presentation::ThemeFeed` asks `GET /themes?started_on=<date>` once as the game starts, when the game has a server (none in an automated run), on a worker thread (`Groups::Worker`), so a frame never waits. `started_on` is the date this device first ran the game, kept once in `started_on.txt`, sent with no token and no account, for Free players too. The answer is a list of `{"key": ...}`.
- `ThemeKeeper#receive` keeps every key the game knows and ignores the rest. A theme once unlocked stays, on this device, offline too, even if a later answer leaves it out. Offline, nothing changes.
- `themes.txt` keeps three lines: `unlocked:`, `told:` and `chosen:`.
- How themes open by their dates while setdef is gone (`Theme#opens_on`, `ThemeKeeper#open_by_date`, `GONE_DAYS`) is in [store-and-pro.md](store-and-pro.md). The request and both files are declared in [privacy.json](../privacy.json) ([privacy.md](privacy.md)).

Using a theme other than Classic is Pro's: a Free player always uses Classic, and sees the others on the Themes screen, where tapping one opens the offer ([store-and-pro.md](store-and-pro.md), [screens.md](screens.md)). `DOT_POPPER_THEME_UNLOCKS=ghost,eclipse` and `DOT_POPPER_THEME=ghost` stand in for the server and the player's choice in GUI scenarios (`App#use_fixture`).

### The Themes screen

Home's Themes tile (RB on a gamepad), whose note names the theme in use, opens the Themes screen over Home's dimmed dots (`Show#open_themes`, `Shell::ThemesPainter`, `Presentation::ThemesLayout`). It has one card for each theme the player has (`ThemeKeeper#shown`: Classic and every unlocked theme), in as few rows as give each card room for its name (one row while they fit), otherwise two to a row. A card is its theme in small: its own night, a bright dot partly under a popped one as in the game, and its name. The theme in use has a thick cream outline and a check, so what is chosen shows without a word. A tap on a card uses it at once, and the whole screen and Home's dots behind it take its colors, so the choice is seen before it is left (Tidwell's Preview); there is no confirm (`Show#use`). LB and RB step to the previous and next theme. A Free player's tap opens the offer over the screen. Back, Escape and B return to Home. The screen's place among the others is in [screens.md](screens.md).

### The new-theme card

A newly unlocked theme is told once, on Home, when nothing else is asked of the player (`Show#arrival`, `Shell::ArrivalPainter`, `Presentation::ArrivalPlan`): a calm moment, never in a game (Saffer, *Microinteractions*: bring the data forward, at the right time; Hodent: attention is scarce). It is a card over Home, not a screen of its own. It shows "A new theme", a preview of the theme's own bright and popped dot, its name, and two buttons: "Not now", and beside it a switch as prominent as Play, "Use <name>" ("Use Ghost"), since a button names the action it takes (Podmajersky; Yifrah). A Free player's switch says "Get Pro" and opens the offer, as tapping Themes does; knowing is free (Ferrara). Either answer, or Escape, tells it for good (`ThemeKeeper#told`), so it is answered in one tap and never asked again (Rigby and Ryan: autonomy). Where the switch's words won't fit beside "Not now", as "Use Jack-o'-lantern" on a phone held sideways, the buttons stack, as they always do on a narrow card such as an upright phone's (`ArrivalPlan#stacked?`).

`test/presentation/theme_keeper_test.rb` (the keeper and the feed, with a fake worker), `test/presentation/themes_test.rb` (the card, Not now, Escape, Free, the switch's word and its fit at 400 × 850 and 850 × 400, and the Themes screen's cards), and `test/gui/scenarios/themes.rb` cover themes. `test/gui/scenarios/themes_gallery.rb`, outside `rake test:gui`, keeps screenshots of one theme's screens to review (`DOT_POPPER_THEME`, `DOT_POPPER_THEME_UNLOCKS`, `DOT_POPPER_GALLERY`).
