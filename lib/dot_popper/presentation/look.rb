# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every presentation setting in one place, as Rules holds every rule:
    # colors, words, type, sizes, timings, easing, and how strong each
    # effect is. Sizes and distances are in radii (R) unless they say
    # otherwise, so the look scales with the dot; durations are seconds.
    module Look
      hex = Color.method(:hex)

      PALETTE = Palette.new(
        ink_top: hex["#1d1a4a"], ink_bottom: hex["#0c0b22"], ink_glow: hex["#2b2766"], ink_edge: hex["#05040f"],
        fresh_light: hex["#fff0bf"], fresh_body: hex["#ffbf52"], fresh_deep: hex["#f07c34"],
        fresh_bounce: hex["#ffd98c"], fresh_rim: hex["#fff6d6"], gloss: hex["#ffffff"], halo: hex["#ffb347"],
        popped_top: hex["#4a4570"], popped_bottom: hex["#37335a"], popped_rim: hex["#8f88bd"],
        popped_crater: hex["#29263f"], popped_lip: hex["#6b6596"],
        shadow: hex["#04030d"], alarm: hex["#ff4f9a"],
        cream: hex["#fff4de"], soft: hex["#b9b3e0"], gain: hex["#7df0c6"], urgent: hex["#ff6a8d"],
        pill: hex["#0c0b22", 0.62], pill_edge: hex["#ffffff", 0.1],
        confetti: [hex["#ffbf52"], hex["#ff8fb8"], hex["#7df0c6"], hex["#b9a6ff"], hex["#fff4de"]].freeze
      )

      WORDS = Words.new(
        title: "Dot Popper",
        play: ByInput.new(touch: "Tap anywhere to play", mouse: "Click anywhere to play", gamepad: "Press A to play"),
        continue: ByInput.new(touch: "Tap to continue", mouse: "Click to continue", gamepad: "Press A to continue"),
        time_up: "Time's up!", new_best: "New best!", best: "Your best", score: "SCORE", time: "TIME",
        covered: ByInput.new(
          touch: ["New dots appear under the popped ones.", "Wait for the bright dot to slide out, then tap it."].freeze,
          mouse: ["New dots appear under the popped ones.", "Wait for the bright dot to slide out, then click it."].freeze,
          gamepad: ["New dots appear under the popped ones.", "Wait for the bright dot to slide out, then pop it."].freeze
        ),
        legend: ByInput.new(touch: ["Tap a bright dot", "Tap a popped dot"].freeze,
                            mouse: ["Click a bright dot", "Click a popped dot"].freeze,
                            gamepad: ["Pop a bright dot", "Hit a popped dot"].freeze),
        share: "Copy my result", copied: "Copied! Paste it anywhere.",
        records: "Your records",
        go_back: ByInput.new(touch: "Tap anywhere to go back", mouse: "Click anywhere to go back",
                             gamepad: "Press B to go back"),
        no_rounds: "Play a round, and your records will appear here.",
        labels: {
          bests: "Your bests with standard dots on screens this size",
          fitted_bests: "Your bests with dots sized to the screen",
          chart_note: "Brighter bars are rounds with standard dots on screens this size.",
          fitted_chart_note: "Brighter bars are rounds with dots sized to the screen.",
          best_score: "Best score", longest_round: "Longest round",
          longest_run: "Most pops in a row without a mistake", fastest_pop: "Fastest pop",
          longest_wait: "Longest wait that ended in a pop",
          totals: "All your rounds", rounds: "Rounds played", pops: "Dots popped", slips: "Mistakes",
          seconds: "Time played", days: "Days played", none: "None yet",
          goal: "Daily goal", streak: "Days in a row you've met it", longest_streak: "Most days in a row"
        }.freeze,
        goals: {
          clean_run: "pop %d bright dots in a row without a mistake",
          patient_pop: "pop a bright dot that has been on screen for at least %d seconds",
          quick_start: "pop %d bright dots in the first 10 seconds of a round",
          long_round: "keep one round going for %d seconds",
          comeback: "finish a round with %d points even after a mistake",
          score: "score %d points in one round",
          clean_round: "score %d points in a round without a single mistake"
        }.freeze,
        goal_done: "Done today:", goal_met: "You met today's goal!",
        screen_size: {
          here: "This screen is about %d dots wide and %d dots tall.",
          played: "Played on a screen about %d dots wide and %d dots tall.",
          fitted_here: "Dots are sized to fit this screen, so scores compare across devices.",
          fitted_played: "Played with dots sized to the screen.",
          choice: "Dot size", standard: "Standard", smaller: "Smaller, more room", bigger: "Bigger, less room",
          alike: "About the same"
        }.freeze
      )

      # The Records screen, opened from the title: the heading's and the
      # rows' sizes, a row's height in its type size, the chart's height in
      # rows, the gap between columns and a column's widest, and how far
      # the title's dots dim behind it. A column is only as wide as its
      # longest row needs, so each label stays near its number.
      RECORDS = RecordsLook.new(heading: 48, text: 23, line: 1.6, chart: 4.2, gap: 56, column: 520, veil: 0.9)

      # The stacking rule, taught on the first two Game Overs after a wrong
      # tap that had the bright dot hidden under the popped one.
      LESSON = LessonLook.new(times: 2, alpha: 1.0)

      # The rounded face, Fredoka (SIL Open Font License; assets/fonts).
      # Sizes are graphics units at a layout scale of 1. A size that
      # animates steps through whole sizes rather than scaling glyphs.
      class Type < Data.define(:bold, :semibold, :title, :heading, :final_score, :hud_number, :hud_label,
                               :prompt, :legend, :best, :floater, :new_best, :hint, :summary); end

      TYPE = Type.new(
        bold: "assets/fonts/Fredoka-Bold.ttf", semibold: "assets/fonts/Fredoka-SemiBold.ttf",
        title: 108, heading: 64, final_score: 136, hud_number: 35, hud_label: 12,
        prompt: 26, legend: 29, best: 26, floater: 34, new_best: 34, hint: 21, summary: 20
      )

      # The desktop window opens at 24 × 16 radii (1200 × 800 units when
      # R is 50), at most 90% of the desktop. R is a fixed physical size,
      # so how crowded the field gets, which is the game's tension, follows
      # the field's size in radii; 24 × 16 is about a tablet's. Phones and
      # tablets play fullscreen.
      WINDOW = WindowLook.new(width: 24, height: 16, most: 0.9)

      LAYOUT = LayoutLook.new(margin: 16, button: 52, reference: 760.0, shrink: 0.7, step: 0.05, least: 12)

      # How a dot is drawn by the dot shader (assets/shaders/dot.glsl),
      # and the edge a player aims at: what is seen of a dot at rest ends
      # at its hit circle, radius 1, with a crisp rim, so a moving target
      # is easy to track. See DotLook.
      DOT = DotLook.new(extent: 1.25, rim: 0.055, shadow_offset: 0.07, shadow_reach: 1.08, shadow_alpha: 0.4,
                        halo_width: 0.035, halo_alpha: 0.16, legend: 0.34)

      MOTION = DotMotion.new(
        spawn: Tween.new(from: 0.15, to: 1.0, duration: 0.42, ease: :out_back),
        pop_stretch: Tween.new(from: 1.3, to: 1.0, duration: 0.6, ease: :out_elastic),
        pop_cover: Tween.new(from: 1.0, to: 0.0, duration: 0.14, ease: :out_quad),
        wobble: Wobble.new(amplitude: 0.13, duration: 0.38, frequency: 11.0)
      )

      # A pop: droplets, a ring, and the new dot's ripple. The droplets and
      # the new best's twinkles are LÖVE particles, drawn from sprites
      # PARTICLE_SPRITE units across, made at the screen's density.
      PARTICLE_SPRITE = 24
      POP_BURST = Burst.new(count: 14, speed: 2.2..5.2, life: 0.25..0.42, size: 0.05..0.11, drag: 3.5,
                            gravity: 3.0, alpha: 0.8)
      SHOCKWAVE = RingLook.new(
        radius: Tween.new(from: 1.0, to: 1.9, duration: 0.36, ease: :out_cubic),
        width: Tween.new(from: 0.14, to: 0.0, duration: 0.36, ease: :out_quad),
        alpha: Tween.new(from: 0.55, to: 0.0, duration: 0.36, ease: :out_quad), color: PALETTE.cream
      )
      SPAWN_RIPPLE = RingLook.new(
        radius: Tween.new(from: 0.3, to: 1.45, duration: 0.55, ease: :out_cubic),
        width: Tween.new(from: 0.09, to: 0.0, duration: 0.55, ease: :linear),
        alpha: Tween.new(from: 0.5, to: 0.0, duration: 0.55, ease: :in_out_sine), color: PALETTE.halo
      )
      # A tap on empty space: only a whisper that the tap was heard.
      TOUCH_RIPPLE = RingLook.new(
        radius: Tween.new(from: 0.12, to: 0.5, duration: 0.25, ease: :out_cubic),
        width: Tween.new(from: 0.05, to: 0.0, duration: 0.25, ease: :linear),
        alpha: Tween.new(from: 0.3, to: 0.0, duration: 0.25, ease: :out_quad), color: PALETTE.soft
      )

      # A wrong tap: the dot shudders and its rim flashes, the screen
      # shakes a little, and the edges glow.
      ALARM_RING = RingLook.new(
        radius: Tween.new(from: 1.0, to: 1.3, duration: 0.3, ease: :out_cubic),
        width: Tween.new(from: 0.14, to: 0.0, duration: 0.3, ease: :out_quad),
        alpha: Tween.new(from: 0.85, to: 0.0, duration: 0.3, ease: :out_quad), color: PALETTE.alarm
      )
      # ...and if the fresh dot was underneath, its outline shows through,
      # so the player sees why: it was under there.
      REVEAL = RevealLook.new(
        radius: Tween.new(from: 1.35, to: 1.04, duration: 0.22, ease: :out_cubic),
        alpha: Tween.new(from: 1.0, to: 0.0, duration: 0.6, ease: :in_quad),
        width: 0.075, dashes: 12, color: PALETTE.fresh_light
      )
      PENALTY_SHAKE = ShakeLook.new(amplitude: 0.12, duration: 0.22, frequency: 24.0)
      # The glow is narrow and quick, so a dot near an edge is tinted only
      # for a moment.
      PENALTY_FLASH = FlashLook.new(color: PALETTE.alarm, alpha: 0.42, duration: 0.32, band: 0.1)
      # The clock's last seconds give each tick a faint glow too.
      TICK_FLASH = FlashLook.new(color: PALETTE.urgent, alpha: 0.16, duration: 0.3, band: 0.12)

      # Floating numbers; +spread+ sets the two of a tap apart, across.
      GAIN_FLOAT = FloaterLook.new(rise: 1.0, life: 0.65)
      LOSS_FLOAT = FloaterLook.new(rise: 0.7, life: 0.75)
      FLOAT_SPREAD = 0.62

      # The HUD's pill is mostly see-through, so a dot under it still
      # shows; its numbers are outlined, so they stay crisp over one.
      HUD = HudLook.new(
        backing: 0.4,
        bump: Tween.new(from: 1.3, to: 1.0, duration: 0.32, ease: :out_back),
        pulse: Tween.new(from: 1.4, to: 1.0, duration: 0.55, ease: :out_elastic),
        urgent_below: 3
      )

      # The title: its drifting dots and how far they dim, the prompt's
      # breath and its faintest point in it, which stays easy to read.
      class TitleLook < Data.define(:dots, :drift, :dim, :breath, :faintest, :intro); end
      TITLE = TitleLook.new(dots: 7, drift: 0.35, dim: 0.76, breath: 2.4, faintest: 0.8,
                            intro: Tween.new(from: 0.0, to: 1.0, duration: 0.5, ease: :out_cubic))
      # The title's "Dot size" choice is offered only where dots sized to
      # the screen would be more than a tenth smaller or bigger than the
      # standard ones; nearer than that, as in the 24 × 16 R window, the
      # two look alike. Each segment shows a dot: the standard one about a
      # third of the segment's height across, the other in proportion to
      # it, from half as big to a little over twice.
      SIZING = SizingLook.new(alike: 0.1, icon: 0.16, icons: 0.5..2.2)
      # ...and the title's words, from its name to its prompt, sit on a
      # faint backing, so a dot drifting behind them dims further.
      TITLE_BACKING = ScrimLook.new(alpha: 0.4, feather: 48, layers: 10, pad: 12)

      # The glow fresh dots and droplets cast on the night under the dots
      # (Shell::Bloom), blurred at half the screen's resolution. A
      # strength of 0 turns it off, as it is: a glow wide enough to see
      # blurs the fresh dot's edge, where the player aims (doc/decisions.md,
      # "A fresh dot's edge is its hit circle"). 0.7 brings it back.
      BLOOM = BloomLook.new(strength: 0.0, sigma: 3.0, passes: 2, resolution: 0.5)

      # Game over: how the round dims, how the score counts up, and the
      # celebration of a new best. Its sparkles may outlive a pop's
      # droplets, because no round is in play behind them.
      class FinaleLook < Data.define(:dim, :arrive, :tally, :prompt, :sparkles, :goal_sparkles, :sparkle_life); end
      FINALE = FinaleLook.new(
        dim: Tween.new(from: 0.0, to: 0.62, duration: 0.5, ease: :out_cubic),
        arrive: Tween.new(from: 0.0, to: 1.0, duration: 0.45, ease: :out_back),
        tally: Tween.new(from: 0.0, to: 1.0, duration: 0.8, ease: :out_cubic),
        prompt: Tween.new(from: 0.0, to: 1.0, duration: 0.35, ease: :out_cubic),
        sparkles: Burst.new(count: 60, speed: 2.0..7.0, life: 0.8..1.4, size: 0.1..0.24, drag: 1.6,
                            gravity: 4.0, alpha: 0.9, spin: 7.0..1.0, sprite: :twinkle),
        goal_sparkles: Burst.new(count: 22, speed: 1.5..4.0, life: 0.6..1.0, size: 0.08..0.16, drag: 2.0,
                                 gravity: 2.5, alpha: 0.85, spin: 6.0..1.0, sprite: :twinkle),
        sparkle_life: 1.4
      )

      # Game Over's words, from "Time's up!" to "Tap to continue", sit on a
      # soft dark backing, 60% at its middle, so they read over the pile;
      # its edges feather out, so the pile still shows around them.
      FINALE_BACKING = ScrimLook.new(alpha: 0.6, feather: 40, layers: 10, pad: 18)

      # After time's up, the round's dots tumble into a pile behind the
      # score, dimmed (Shell::Pile, with Box2D). A calm pile
      # (DOT_POPPER_CALM) falls slowly and settles without a bounce.
      PILE = PileLook.new(meter: 2.0, gravity: 20.0, restitution: 0.35, friction: 0.4, density: 1.0, damping: 0.05,
                          fling: 1.0, longest_step: 1 / 30.0)
      CALM_PILE = PILE.with(gravity: 8.0, restitution: 0.0, friction: 0.8, damping: 2.5, fling: 0.25)

      # Playing with the pile (Presentation::Tilt): tilting a tablet, or
      # pushing a gamepad's right stick, turns its gravity, and a shake
      # throws the dots up. The filter's fifth of a second keeps a hand's
      # tremor out of the dots without lagging a turn; a jolt of over 0.8 g
      # is a shake, past the bump of setting a tablet down. A shake throws
      # hard, several times a dot's fastest speed, because a toss no
      # bigger than a tilt reads as nothing (the first iPad playtest). A calm pile
      # turns slowly and never throws.
      TILT = TiltLook.new(smoothing: 0.2, wake: 0.05, shake: 0.8, settle: 0.3, cooldown: 0.6, kick: 24.0,
                          most_kick: 36.0, shakes: true, fling: Throw.new(spread: 1.0, least: 0.5), dead_zone: 0.2,
                          hint_rounds: 3, hint_alpha: 0.7,
                          tilt_hint: "Tilt your %s to roll the dots.",
                          stick_hint: "Hold A on a dot to drag it, or push the right stick to roll them.",
                          drag_hint: "Drag the dots to play with them.",
                          drag_tilt_hint: "Drag the dots, or tilt your %s to roll them.")
      CALM_TILT = TILT.with(smoothing: 0.8, shakes: false)

      # Dragging the pile (Presentation::PileGrabs): a press on a dot that
      # wanders a quarter of a radius, about a finger's wobble, or stays
      # down for 0.15 s holds it; a quicker, stiller press is a click. A
      # held dot catches up with the pointer in a few frames, and is
      # thrown at the pointer's speed over its last tenth of a second,
      # which a calm pile caps low, so a flick only nudges it.
      GRAB = GrabLook.new(slop: 0.25, hold: 0.15, follow: 0.05, fastest: 60.0, fling: 40.0, window: 0.1)
      CALM_GRAB = GRAB.with(follow: 0.12, fastest: 20.0, fling: 6.0)

      # Sound: the pop climbs a little with the score, up to a cap. A pop
      # or a wrong tap is heard where it is across the screen, leaning at
      # most 60% to a side.
      class SoundLook < Data.define(:pop_climb, :pop_highest, :tick_climb, :volume, :stereo); end
      SOUND = SoundLook.new(pop_climb: 0.02, pop_highest: 1.4, tick_climb: 0.12, volume: 0.8,
                            stereo: Stereo.new(spread: 0.6))

      # A short buzz under the finger for a pop, a longer one for a wrong
      # tap, on phones and tablets that can (Shell::Haptics).
      HAPTICS = HapticsLook.new(pop: 0.015, penalty: 0.04)

      # The gamepad cursor (Lota 0.1.3 and newer). At full tilt it crosses
      # the window corner to corner in a second, whatever the window's
      # size, and never slower than 16 R/s, nearly three times the fastest
      # dot (6 R/s), which crosses a small 24 R window in 1.5 s. It gathers
      # that speed over 0.3 s; the squared curve leaves half a tilt at a
      # quarter of it, for aiming. The reticle is thin and open in the
      # middle, so it never hides the dot under it.
      GAMEPAD = GamepadLook.new(dead_zone: 0.2, curve: 2.0, speed: 16.0, crossing: 1.0, ramp: 0.3, trigger_press: 0.5,
                                trigger_release: 0.3, ring: 0.3, ticks: 0.42..0.6, line: 0.04, pip: 4)

      PATCHES = {
        # A bubbly "bloop": a sine that swoops up, with a soft click.
        pop: Patch.new(notes: [
          Note.new(wave: :sine, from: 360, to: 980, length: 0.12, volume: 1.0),
          Note.new(wave: :sine, from: 720, to: 1960, length: 0.07, volume: 0.25),
          Note.new(wave: :noise, from: 1, length: 0.012, attack: 0.001, volume: 0.25)
        ]),
        # A low, dull "bonk", falling.
        bonk: Patch.new(notes: [
          Note.new(wave: :triangle, from: 210, to: 92, length: 0.26, volume: 1.0),
          Note.new(wave: :square, from: 105, to: 70, length: 0.16, volume: 0.35),
          Note.new(wave: :noise, from: 1, length: 0.03, attack: 0.001, volume: 0.4)
        ]),
        # A woodblock tick for the last seconds.
        tick: Patch.new(notes: [
          Note.new(wave: :sine, from: 1760, to: 1500, length: 0.05, attack: 0.001, volume: 1.0),
          Note.new(wave: :triangle, from: 880, length: 0.03, attack: 0.001, volume: 0.4)
        ]),
        # Three notes up: off you go.
        start: Patch.new(notes: [
          Note.new(wave: :triangle, from: 523.25, start: 0.0, length: 0.12, volume: 0.8),
          Note.new(wave: :triangle, from: 659.25, start: 0.07, length: 0.12, volume: 0.8),
          Note.new(wave: :triangle, from: 783.99, start: 0.14, length: 0.22, volume: 0.9),
          Note.new(wave: :sine, from: 1567.98, start: 0.14, length: 0.2, volume: 0.2)
        ]),
        # Three notes down: time's up.
        game_over: Patch.new(notes: [
          Note.new(wave: :triangle, from: 587.33, start: 0.0, length: 0.16, volume: 0.8),
          Note.new(wave: :triangle, from: 440.0, start: 0.13, length: 0.18, volume: 0.8),
          Note.new(wave: :triangle, from: 349.23, start: 0.28, length: 0.4, volume: 0.9)
        ]),
        # A bright arpeggio with a bell's shimmer.
        new_best: Patch.new(notes: [523.25, 659.25, 783.99, 1046.5].each_with_index.flat_map do |hz, i|
          [Note.new(wave: :sine, from: hz, start: i * 0.08, length: 0.4, volume: 0.8),
           Note.new(wave: :sine, from: hz * 2, start: i * 0.08, length: 0.25, volume: 0.25)]
        end + [Note.new(wave: :sine, from: 2093, start: 0.34, length: 0.5, volume: 0.3)])
      }.freeze

      # The autoplay bot, for development (main.rb): how long it waits on
      # each screen, the Records screen too, how long it thinks before each
      # tap (which grows with the score, so a round ends), and how often it
      # taps a popped dot.
      class AutopilotLook < Data.define(:title_wait, :finale_wait, :records_wait, :think, :tiring, :mistakes); end
      AUTOPILOT = AutopilotLook.new(title_wait: 1.6, finale_wait: 3.2, records_wait: 3.0, think: 0.22..0.45,
                                    tiring: 0.07, mistakes: 0.2)
    end
  end
end
