# frozen_string_literal: true

module DotPopper
  module Presentation
    # Every presentation setting in one place, as Rules holds every rule:
    # colors, words, type, sizes, timings, easing, and how strong each
    # effect is. Sizes and distances are in radii (R) unless they say
    # otherwise, so the theme scales with the dot; durations are seconds.
    module Style
      hex = Color.method(:hex)

      PALETTE = Palette.new(
        ink_top: hex["#1d1a4a"], ink_bottom: hex["#0c0b22"], ink_glow: hex["#2b2766"], ink_edge: hex["#05040f"],
        fresh_light: hex["#fff0bf"], fresh_body: hex["#ffbf52"], fresh_deep: hex["#f07c34"],
        fresh_bounce: hex["#ffd98c"], fresh_rim: hex["#fff6d6"], gloss: hex["#ffffff"], halo: hex["#ffb347"],
        bonus_light: hex["#e6fff6"], bonus_body: hex["#6fe9c5"], bonus_deep: hex["#1fae96"],
        bonus_bounce: hex["#b4fbe6"], bonus_rim: hex["#f2fffa"], bonus_mark: hex["#1d1a4a"],
        popped_top: hex["#4a4570"], popped_bottom: hex["#37335a"], popped_rim: hex["#8f88bd"],
        popped_crater: hex["#29263f"], popped_lip: hex["#6b6596"],
        shadow: hex["#04030d"], alarm: hex["#ff4f9a"],
        cream: hex["#fff4de"], soft: hex["#b9b3e0"], gain: hex["#7df0c6"], urgent: hex["#ff6a8d"],
        pill: hex["#0c0b22", 0.62], pill_edge: hex["#ffffff", 0.1],
        confetti: [hex["#ffbf52"], hex["#ff8fb8"], hex["#7df0c6"], hex["#b9a6ff"], hex["#fff4de"]].freeze
      )

      # The themes the game can use, the ordinary one first (ThemeKeeper).
      # The others exist for a player only once the server has said so;
      # each is its own file in presentation/themes/. Every one keeps a
      # fresh dot bright against a dark popped one, by shape and lightness,
      # not hue alone.
      THEMES = [
        Theme.new(key: :classic, palette: PALETTE),
        Themes::Ghost.theme(PALETTE, hex),
        Themes::JackOLantern.theme(PALETTE, hex),
        Themes::Awake.theme(PALETTE, hex),
        Themes::Eclipse.theme(PALETTE, hex)
      ].freeze

      WORDS = Words.new(
        game_name: "Dot Popper",
        play: ByInput.new(touch: "Play", mouse: "Play", gamepad: "Play (A)"),
        play_again: ByInput.new(touch: "Play again", mouse: "Play again", gamepad: "Play again (A)"),
        time_up: "Time's up!", new_score_record: "New record!", score_record: "Your record", score: "SCORE", time: "TIME",
        share: ByInput.new(touch: "Share my score", mouse: "Share my score", gamepad: "Share my score (Y)"),
        share_heading: "Share your score",
        copied: "Copied! Paste it anywhere.",
        copy: ByInput.new(touch: "Copy", mouse: "Copy", gamepad: "Copy (A)"),
        close: ByInput.new(touch: "Close", mouse: "Close", gamepad: "Close (B)"),
        stats: "Stats",
        how_to_play: ByInput.new(touch: "How to play", mouse: "How to play", gamepad: "How to play (Y)"),
        go_back: ByInput.new(touch: "Back", mouse: "Back", gamepad: "Back (B)"),
        no_games: "Play a game, and your stats will appear here.",
        clear: ByInput.new(touch: "Clear my stats…", mouse: "Clear my stats…",
                           gamepad: "Hold Y to clear my stats…"),
        keep_holding: ByInput.new(
          touch: "Keep holding to clear your records, totals, chart, achievements, and streak.",
          mouse: "Keep holding to clear your records, totals, chart, achievements, and streak.",
          gamepad: "Keep holding %s to clear your records, totals, chart, achievements, and streak."
        ),
        quit_again: "Press B again to quit",
        quit: ByInput.new(touch: "Quit", mouse: "Quit", gamepad: "Quit (B)"),
        # The Themes screen: its button's word and heading, and each theme's name.
        themes: { title: "Themes", new: "A new theme", later: "Not now", use: "Use %s", classic: "Classic", ghost: "Ghost", jack_o_lantern: "Jack-o'-lantern", awake: "Awake", eclipse: "Eclipse" }.freeze,
        offer: {
          entry: "Get Pro", heading: "Dot Popper Pro", no_games: "No games left today.",
          includes: { games: "Unlimited games", achievements: "Achievements", themes: "Themes", groups: "Friend groups" }.freeze,
          buy: "Buy for %s", retry: "Try again", restore: "Restore Purchases",
          loading: "Asking the store…", busy: "One moment…", pending: "Waiting for approval.",
          failed: "That didn't go through.", none: "Nothing to restore on this account.",
          unavailable: "The store isn't answering.", thanks: "Thank you. It's yours.",
          paste: "Paste license key", browser: "Finish in your browser. Your key comes by email.",
          copied: "Your license key is copied. Paste it here.", invalid: "That isn't a license key.",
          typing: "Key:", empty: "Copy your license key first.", same: "That key is already here.", not_sold: "Pro is no longer sold."
        }.freeze,
        hold_to_clear: ByInput.new(
          touch: "Press and hold to clear your records, totals, chart, achievements, and streak.",
          mouse: "Press and hold to clear your records, totals, chart, achievements, and streak.",
          gamepad: "Hold Y to clear your records, totals, chart, achievements, and streak."
        ),
        credits: ByInput.new(touch: "Credits", mouse: "Credits", gamepad: "Credits (X)"),
        credits_title: "Credits",
        # The Credits screen's own words. A later line of thanks goes in
        # as +thanks:+, which the screen leaves out while there is none.
        notice: {
          made_by: "Made by setdef",
          copyright: "Dot Popper © 2026 setdef", reserved: "All rights reserved.",
          open_source: "Open-source licenses",
          font_name: "Fredoka",
          font: "The letters are Fredoka, Copyright 2016 The Fredoka Project Authors, under the SIL Open Font " \
                "License, version 1.1.",
          mono_name: "Iosevka",
          mono: "Iosevka, copyright (c) 2015-2026 Renzhi Li (aka. Belleve Invis), under the SIL Open Font " \
                "License, version 1.1. It sets the license texts below.",
          emoji_name: "Noto Emoji",
          emoji: "The tutorial's pointing hand is Noto Emoji's, copyright 2013 Google, Inc., under the Apache " \
                 "License, version 2.0.",
          wordlists_name: "imsky/wordlists",
          wordlists: "The names of friend groups and their members use Ivan Malopinsky's wordlists, under the MIT License.",
          lota: "Lota", fledge: "Fledge"
        }.freeze,
        cleared: "Stats cleared.", undo: ByInput.new(touch: "Undo", mouse: "Undo", gamepad: "Undo (Y)"),
        labels: {
          records: "Your stats with standard dots on screens this size",
          fitted_records: "Your stats with dots sized to the screen",
          chart_note: "Brighter bars are games with standard dots on screens this size.",
          fitted_chart_note: "Brighter bars are games with dots sized to the screen.",
          score_record: "Highest score", longest_game: "Longest game",
          most_dots_in_a_row: "Most dots in a row without a mistake", shortest_time_to_pop: "Shortest Time to Pop",
          longest_time_to_pop: "Longest Time to Pop",
          totals: "All your games", games: "Games played", pops: "Dots popped", mistakes: "Mistakes",
          seconds: "Time played", days: "Days played", none: "None yet",
          goal: "Daily goal", streak: "Days in a row", longest_streak: "Most days in a row"
        }.freeze,
        goals: {
          clean_run: "pop %d bright dots in a row without a mistake",
          patient_pop: "pop a bright dot that has been on screen for at least %d seconds",
          quick_start: "pop %d bright dots in the first 10 seconds of a game",
          long_game: "keep one game going for %d seconds",
          comeback: "finish a game with %d points even after a mistake",
          score: "score %d points in one game",
          clean_game: "score %d points in a game without a single mistake"
        }.freeze,
        goal_done: "Done today:", goal_met: "You met today's goal!",
        screen_size: {
          here: "This screen is about %d dots wide and %d dots tall.",
          played: "Played on a screen about %d dots wide and %d dots tall.",
          fitted_played: "Played with dots sized to the screen.",
          choice: "Dot size", smaller: "Smaller", bigger: "Bigger", smaller_note: "More room",
          bigger_note: "Less room", alike_note: "",
          alike: "About the same"
        }.freeze,
        # The redesigned screens' words, said for each input where a
        # controller's button is named.
        buttons: {
          settings: ByInput.new(touch: "Settings", mouse: "Settings", gamepad: "Settings (Select)"),
          skip: ByInput.new(touch: "Skip", mouse: "Skip", gamepad: "Skip (B)"),
          get_pro: "Get Pro", home: ByInput.new(touch: "Home", mouse: "Home", gamepad: "Home (B)"),
          tile_stats: "Stats", tile_achievements: "Achievements", tile_themes: "Themes", tile_groups: "Friend groups",
          tile_note_to_earn: "#{Achievement::IDS.size} to earn", tile_note_take_title: "Join or create",
          badge_stats: "X", badge_achievements: "LB", badge_themes: "RB", badge_groups: "LT",
          goal_label: "Today's goal", in_a_row: "in a row",
          sound: ByInput.new(touch: "Sound", mouse: "Sound", gamepad: "Sound (Select)"),
          dot_size: ByInput.new(touch: "Dot size", mouse: "Dot size", gamepad: "Dot size (LB)"),
          display: ByInput.new(touch: "Display", mouse: "Display", gamepad: "Display (RB)"),
          on: "On", off: "Off", windowed: "Window", full_screen_borderless: "Borderless", full_screen: "Full screen",
          credits_licenses: ByInput.new(touch: "Credits and licenses", mouse: "Credits and licenses", gamepad: "Credits and licenses (X)"),
          privacy: ByInput.new(touch: "Privacy", mouse: "Privacy", gamepad: "Privacy (Y)"),
          privacy_policy: ByInput.new(touch: "Read the privacy policy", mouse: "Read the privacy policy", gamepad: "Read the privacy policy (X)"),
          privacy_delete: "Delete my friend group data",
          privacy_hold: ByInput.new(touch: "Hold to leave every friend group and delete your scores online.", mouse: "Hold to leave every friend group and delete your scores online.", gamepad: "Hold Y to leave every friend group and delete your scores online."),
          privacy_delete_note: "Your Stats stay.",
          server: "Change Server", server_title: "Change Server",
          server_warning: "The server you choose receives your friend group scores. It can't give you Pro.",
          server_how: "Copy the address of a server for Dot Popper, starting https://, and paste it here.",
          server_now: "Now: %s", server_setdef: "setdef's server",
          server_paste: "Paste server address", server_reset: "Use setdef's server",
          server_chosen: "Friend groups use it from the next start.", server_not_https: "That isn't an https:// address.",
          server_empty: "Copy the server's address first.",
          privacy_stats: "Your Stats stay on this device.",
          privacy_groups: "In a friend group, Dot Popper keeps your scores online so the group can see them.",
          not_earned: "Not earned yet", your_record: "Your record", settings_title: "Settings", privacy_title: "Privacy",
          achievements_title: "Achievements", credits_title: "Credits and licenses",
          achievement_close: ByInput.new(touch: "Close", mouse: "Close", gamepad: "Close (B)"),
          achievement_pro: ByInput.new(touch: "Get Pro", mouse: "Get Pro", gamepad: "Get Pro (A)"),
          how_to_earn: ByInput.new(touch: "How to earn", mouse: "How to earn", gamepad: "How to earn (X)")
        }.freeze
      )

      # The Stats screen, opened from the title: the heading's and the
      # rows' sizes, a row's height in its type size, the chart's height in
      # rows, the gap between columns and a column's widest, and how far
      # the title's dots dim behind it. A column is only as wide as its
      # longest row needs, so each label stays near its number.
      RECORDS = StatsStyle.new(heading: 48, text: 23, line: 1.6, chart: 4.2, gap: 56, column: 520, veil: 0.9)

      # The Themes screen, over the Stats screen: its heading's size, the
      # gap between cards in margins, a card's height in its width, and the
      # widest a card grows (in units at a scale of 1).
      THEMES_LAYOUT = ThemesStyle.new(heading: 48, gap: 1.0, ratio: 0.78, widest: 260)

      # The Friend group screen, opened from the title.
      GROUPS = GroupStyle.new(heading: 44, text: 20, column: 560, veil: 0.9)

      # The Credits screen, over the Stats screen: its type, the lines a
      # wheel's notch and a stick at full tilt move it.
      CREDITS = CreditsStyle.new(text: 20, line: 1.5, column: 680, wheel: 3, stick: 14)

      # Clearing the records, from the Stats screen: "Clear my stats…"
      # is held for two seconds, never only tapped, and Undo is offered
      # for ten after. A press let go too soon leaves its hint, to hold
      # it, for a moment.
      RECORDS_CLEAR = ClearStyle.new(hold: 2.0, undo: 10.0, hint: 2.5)

      # A button the mouse is over brightens, its backing to the night's
      # glow and its outline to cream, in an eighth of a second, quick
      # enough to answer the hand and soft enough not to flicker as the
      # pointer crosses an edge. Only the mouse hovers: a finger or a
      # gamepad never does.
      HOVER = HoverStyle.new(seconds: 0.12, fill: hex["#2b2766", 0.9], edge: hex["#fff4de"])

      # The stacking rule, taught on the first two Game Overs after a wrong
      # tap that had the bright dot hidden under the popped one: the tap's
      # penalty replays on the pile three times, 2.4 s apart, slowly
      # enough to watch, and then the pile is left in peace.
      LESSON = LessonStyle.new(times: 2, every: 2.4, replays: 3)

      # The tutorial on a first Play (Presentation::Tutorial), which says
      # nothing in words. Its dots move at the game's slowest speed, and
      # time eases to a stop in 0.15 s, never in a snap. The dim around its
      # spotlight leaves what it lights clear by half a dot; the guide taps
      # once every 1.6 s, resting down and to the right of the dot, where
      # it hides none of it. Once it has tapped the popped dot to show the
      # cost, it waits well above it, its whole hand clear of both
      # dots, and on screen wherever they are, and wags its finger, "no":
      # twice side to side in 0.8 s, 12° each way about the wrist, then
      # holds still 0.25 s. Time stays stopped while the cost's
      # "−2"s float and the hand reaches its place, then flows at 0.6 while
      # it wags. In the game, the clock's spotlight fades in 0.6 s, so the
      # game's dots are never hidden; its halo lasts past the first tick.
      TUTORIAL = TutorialStyle.new(
        drift: 1.0, stop: 0.15, resume: 0.5, slow: 0.6, start: [-0.27, -0.12].freeze, born: 0.1, peek: 0.8,
        clear: 2.3, flight: 0.42, quick: 0.45, gap: 0.12, hold: 0.3, linger: 0.35, handover: 0.35,
        longest: 5.0,
        spotlight: SpotlightStyle.new(dim: 0.62, move: 0.35, feather: 0.9, dot: 1.5),
        ghost: GhostStyle.new(loop: 1.6, glide: 0.5, fade: 0.25, rest: [0.75, 0.9].freeze, hover: [-0.2, -4.6].freeze,
                             wag: WagStyle.new(cycles: 2, time: 0.8, angle: 0.21), settle: 0.25),
        lead: LeadStyle.new(dim: 0.6, halo: 1.3, fade: 0.4),
        notice: 0.9
      )
      # A calm tutorial's guide (DOT_POPPER_CALM) wags gentler: half as
      # far, and slower.
      CALM_WAG = WagStyle.new(cycles: 2, time: 1.0, angle: 0.1)

      # The rounded face, Fredoka (SIL Open Font License; assets/fonts).
      # Sizes are graphics units at a layout scale of 1. A size that
      # animates steps through whole sizes rather than scaling glyphs.
      class Type < Data.define(:bold, :semibold, :game_name, :heading, :final_score, :hud_number, :hud_label,
                               :prompt, :legend, :score_record, :floater, :new_score_record, :hint, :summary, :wordmark, :mono); end

      TYPE = Type.new(
        bold: "assets/fonts/Fredoka-Bold.ttf", semibold: "assets/fonts/Fredoka-SemiBold.ttf",
        wordmark: "assets/fonts/Iosevka-Bold-setdef.ttf", mono: "assets/fonts/Iosevka-Regular-latin.ttf",
        game_name: 108, heading: 64, final_score: 136, hud_number: 35, hud_label: 12,
        prompt: 26, legend: 29, score_record: 26, floater: 34, new_score_record: 34, hint: 21, summary: 20
      )

      # setdef's splash: the maker's near-black ground and setdef's amber
      # (brand/README.md), which draws the logotype and its block.
      SPLASH_INK = hex["#09090b"]
      SPLASH_YELLOW = hex["#fbbf24"]

      # The desktop window opens at 24 × 16 radii (1200 × 800 units when
      # R is 50), at most 90% of the desktop. R is a fixed physical size,
      # so how crowded the field gets, which is the game's tension, follows
      # the field's size in radii; 24 × 16 is about a tablet's. Phones and
      # tablets play fullscreen.
      WINDOW = WindowStyle.new(width: 24, height: 16, most: 0.9)

      LAYOUT = LayoutStyle.new(margin: 16, button: 52, reference: 760.0, shrink: 0.7, step: 0.05, least: 12)

      # How a dot is drawn by the dot shader (assets/shaders/dot.glsl),
      # and the edge a player aims at: what is seen of a dot at rest ends
      # at its hit circle, radius 1, with a crisp rim, so a moving target
      # is easy to track. See DotStyle.
      DOT = DotStyle.new(extent: 1.25, rim: 0.055, shadow_offset: 0.07, shadow_reach: 1.08, shadow_alpha: 0.4,
                        halo_width: 0.035, halo_alpha: 0.16, legend: 0.34)

      MOTION = DotMotion.new(
        spawn: Tween.new(from: 0.15, to: 1.0, duration: 0.42, ease: :out_back),
        pop_stretch: Tween.new(from: 1.3, to: 1.0, duration: 0.6, ease: :out_elastic),
        pop_cover: Tween.new(from: 1.0, to: 0.0, duration: 0.14, ease: :out_quad),
        wobble: Wobble.new(amplitude: 0.13, duration: 0.38, frequency: 11.0)
      )

      # A pop: droplets, a ring, and the new dot's ripple. The droplets and
      # the new record's twinkles are LÖVE particles, drawn from sprites
      # PARTICLE_SPRITE units across, made at the screen's density.
      PARTICLE_SPRITE = 24
      POP_BURST = Burst.new(count: 14, speed: 2.2..5.2, life: 0.25..0.42, size: 0.05..0.11, drag: 3.5,
                            gravity: 3.0, alpha: 0.8)
      SHOCKWAVE = RingStyle.new(
        radius: Tween.new(from: 1.0, to: 1.9, duration: 0.36, ease: :out_cubic),
        width: Tween.new(from: 0.14, to: 0.0, duration: 0.36, ease: :out_quad),
        alpha: Tween.new(from: 0.55, to: 0.0, duration: 0.36, ease: :out_quad), color: PALETTE.cream
      )
      SPAWN_RIPPLE = RingStyle.new(
        radius: Tween.new(from: 0.3, to: 1.45, duration: 0.55, ease: :out_cubic),
        width: Tween.new(from: 0.09, to: 0.0, duration: 0.55, ease: :linear),
        alpha: Tween.new(from: 0.5, to: 0.0, duration: 0.55, ease: :in_out_sine), color: PALETTE.halo
      )
      # A tap on empty space: only a whisper that the tap was heard.
      TOUCH_RIPPLE = RingStyle.new(
        radius: Tween.new(from: 0.12, to: 0.5, duration: 0.25, ease: :out_cubic),
        width: Tween.new(from: 0.05, to: 0.0, duration: 0.25, ease: :linear),
        alpha: Tween.new(from: 0.3, to: 0.0, duration: 0.25, ease: :out_quad), color: PALETTE.soft
      )

      # A bonus dot (Rules::BONUS), earned by a row: it appears in a
      # wider mint ripple, and pulses a ring now and then while it waits,
      # so the eye finds it among the dots (outlines only; they hide no
      # dot). Popped, it bursts larger and in more colors, with a second,
      # wider shockwave.
      BONUS_BEACON_EVERY = 0.9
      BONUS_CONFETTI = [PALETTE.bonus_body, PALETTE.bonus_light, PALETTE.cream, PALETTE.confetti.first].freeze
      BONUS_RIPPLE = RingStyle.new(
        radius: Tween.new(from: 0.3, to: 2.2, duration: 0.7, ease: :out_cubic),
        width: Tween.new(from: 0.12, to: 0.0, duration: 0.7, ease: :linear),
        alpha: Tween.new(from: 0.8, to: 0.0, duration: 0.7, ease: :in_out_sine), color: PALETTE.bonus_body
      )
      BONUS_BEACON = RingStyle.new(
        radius: Tween.new(from: 1.05, to: 1.7, duration: 0.6, ease: :out_cubic),
        width: Tween.new(from: 0.06, to: 0.0, duration: 0.6, ease: :linear),
        alpha: Tween.new(from: 0.55, to: 0.0, duration: 0.6, ease: :out_quad), color: PALETTE.bonus_body
      )
      BONUS_BURST = Burst.new(count: 26, speed: 2.6..6.4, life: 0.3..0.45, size: 0.06..0.13, drag: 3.5,
                              gravity: 3.0, alpha: 0.9)
      BONUS_SHOCKWAVE = RingStyle.new(
        radius: Tween.new(from: 1.0, to: 2.8, duration: 0.45, ease: :out_cubic),
        width: Tween.new(from: 0.2, to: 0.0, duration: 0.45, ease: :out_quad),
        alpha: Tween.new(from: 0.8, to: 0.0, duration: 0.45, ease: :out_quad), color: PALETTE.bonus_body
      )

      # A wrong tap: the dot shudders and its rim flashes, the screen
      # shakes a little, and the edges glow.
      ALARM_RING = RingStyle.new(
        radius: Tween.new(from: 1.0, to: 1.3, duration: 0.3, ease: :out_cubic),
        width: Tween.new(from: 0.14, to: 0.0, duration: 0.3, ease: :out_quad),
        alpha: Tween.new(from: 0.85, to: 0.0, duration: 0.3, ease: :out_quad), color: PALETTE.alarm
      )
      # ...and if the fresh dot was underneath, its outline shows through,
      # so the player sees why: it was under there.
      REVEAL = RevealStyle.new(
        radius: Tween.new(from: 1.35, to: 1.04, duration: 0.22, ease: :out_cubic),
        alpha: Tween.new(from: 1.0, to: 0.0, duration: 0.6, ease: :in_quad),
        width: 0.075, dashes: 12, color: PALETTE.fresh_light
      )
      PENALTY_SHAKE = ShakeStyle.new(amplitude: 0.12, duration: 0.22, frequency: 24.0)
      # The glow is narrow and quick, so a dot near an edge is tinted only
      # for a moment.
      PENALTY_FLASH = FlashStyle.new(color: PALETTE.alarm, alpha: 0.42, duration: 0.32, band: 0.1)
      # The clock's last seconds give each tick a faint glow too.
      TICK_FLASH = FlashStyle.new(color: PALETTE.urgent, alpha: 0.16, duration: 0.3, band: 0.12)

      # Floating numbers; +spread+ sets the two of a tap apart, across.
      GAIN_FLOAT = FloaterStyle.new(rise: 1.0, life: 0.65)
      LOSS_FLOAT = FloaterStyle.new(rise: 0.7, life: 0.75)
      FLOAT_SPREAD = 0.62

      # The HUD's pill is mostly see-through, so a dot under it still
      # shows; its numbers are outlined, so they stay crisp over one.
      HUD = HudStyle.new(
        backing: 0.4,
        bump: Tween.new(from: 1.3, to: 1.0, duration: 0.32, ease: :out_back),
        pulse: Tween.new(from: 1.4, to: 1.0, duration: 0.55, ease: :out_elastic),
        urgent_below: 3
      )

      # The title: its drifting dots and how far they dim, the prompt's
      # breath and its faintest point in it, which stays easy to read.
      class HomeStyle < Data.define(:dots, :drift, :dim, :breath, :faintest, :intro); end
      HOME = HomeStyle.new(dots: 7, drift: 0.35, dim: 0.76, breath: 2.4, faintest: 0.8,
                            intro: Tween.new(from: 0.0, to: 1.0, duration: 0.5, ease: :out_cubic))
      # The title's "Dot size" choice is offered only where dots sized to
      # the screen would be more than a tenth smaller or bigger than the
      # standard ones; nearer than that, as in the 24 × 16 R window, the
      # two look alike. Each segment shows a dot: the standard one about a
      # third of the segment's height across, the other in proportion to
      # it, from half as big to a little over twice.
      SIZING = SizingStyle.new(alike: 0.1, icon: 0.16, icons: 0.5..2.2)
      # ...and the title's words, from its name to its prompt, sit on a
      # faint backing, so a dot drifting behind them dims further.
      HOME_BACKING = ScrimStyle.new(alpha: 0.4, feather: 48, layers: 10, pad: 12)

      # The glow fresh dots and droplets cast on the night under the dots
      # (Shell::Bloom), blurred at half the screen's resolution. A
      # strength of 0 turns it off, as it is: a glow wide enough to see
      # blurs the fresh dot's edge, where the player aims
      # (doc/design/look-and-sound.md). 0.7 brings it back.
      BLOOM = BloomStyle.new(strength: 0.0, sigma: 3.0, passes: 2, resolution: 0.5)

      # Game over: how the game dims, how the score counts up, and the
      # celebration of a new record. Its sparkles may outlive a pop's
      # droplets, because no game is in play behind them.
      class GameOverStyle < Data.define(:dim, :arrive, :tally, :prompt, :sparkles, :goal_sparkles, :sparkle_life,
                                     :share); end
      GAME_OVER = GameOverStyle.new(
        dim: Tween.new(from: 0.0, to: 0.62, duration: 0.5, ease: :out_cubic),
        arrive: Tween.new(from: 0.0, to: 1.0, duration: 0.45, ease: :out_back),
        tally: Tween.new(from: 0.0, to: 1.0, duration: 0.8, ease: :out_cubic),
        prompt: Tween.new(from: 0.0, to: 1.0, duration: 0.35, ease: :out_cubic),
        sparkles: Burst.new(count: 60, speed: 2.0..7.0, life: 0.8..1.4, size: 0.1..0.24, drag: 1.6,
                            gravity: 4.0, alpha: 0.9, spin: 7.0..1.0, sprite: :twinkle),
        goal_sparkles: Burst.new(count: 22, speed: 1.5..4.0, life: 0.6..1.0, size: 0.08..0.16, drag: 2.0,
                                 gravity: 2.5, alpha: 0.85, spin: 6.0..1.0, sprite: :twinkle),
        sparkle_life: 1.4,
        # "Share my score" rises into place as the score lands, rings
        # once, and rises further and rings brighter on a new record.
        share: ShareCueStyle.new(arrive: Tween.new(from: 0.0, to: 1.0, duration: 0.5, ease: :out_back), lift: 12,
                                score_record_lift: 28, score_record_delay: 0.15,
                                ring: Tween.new(from: 0.0, to: 1.0, duration: 0.8, ease: :out_cubic),
                                ring_reach: 10, ring_alpha: 0.45, score_record_ring_reach: 18, score_record_ring_alpha: 0.9)
      )

      # The share preview, over Game Over: it comes in quickly, lifting
      # into place; "Copied!" fades in. The card is at most +width+ units
      # across at a layout scale of 1, padded by +pad+, with its message
      # padded by +bubble+, and the screen behind it veiled by +veil+.
      SHARE_PREVIEW = SharePreviewStyle.new(arrive: Tween.new(from: 0.0, to: 1.0, duration: 0.22, ease: :out_cubic),
                                           confirm: Tween.new(from: 0.0, to: 1.0, duration: 0.25, ease: :out_cubic),
                                           lift: 14, width: 680, pad: 24, bubble: 14, veil: 0.6)

      # Game Over's words, from "Time's up!" to the Continue button, sit on a
      # soft dark backing, 60% at its middle, so they read over the pile;
      # its edges feather out, so the pile still shows around them.
      GAME_OVER_BACKING = ScrimStyle.new(alpha: 0.6, feather: 40, layers: 10, pad: 18)

      # After time's up, the game's dots tumble into a pile behind the
      # score, dimmed (Shell::Pile, with Box2D). A calm pile
      # (DOT_POPPER_CALM) falls slowly and settles without a bounce.
      PILE = PileStyle.new(meter: 2.0, gravity: 20.0, restitution: 0.35, friction: 0.4, density: 1.0, damping: 0.05,
                          fling: 1.0, longest_step: 1 / 30.0)
      CALM_PILE = PILE.with(gravity: 8.0, restitution: 0.0, friction: 0.8, damping: 2.5, fling: 0.25)

      # Playing with the pile (Presentation::Tilt): tilting a tablet, or
      # pushing a gamepad's right stick, turns its gravity, and a shake
      # throws the dots up. The filter's fifth of a second keeps a hand's
      # tremor out of the dots without lagging a turn. A shake is a jolt
      # of over 1 g and a jolt back the other way within 0.35 seconds, as a
      # hand shakes: a single bump, such as a footstep while walking with
      # the phone (the Android playtest), never counts. A shake throws hard: at
      # least 20 radii a second, and each ball at least 0.6 of that, so the
      # gentlest toss is twice a dot's fastest speed, and a hard shake up
      # to 108, three times what it was, because the iPhone playtest found
      # the toss "not as much/violent as I'd expect". It makes no sound and
      # no flash: the dots flying is the whole answer. A calm pile turns
      # slowly and never throws.
      TILT = TiltStyle.new(smoothing: 0.2, wake: 0.05, shake: 1.0, reversal: 0.35, settle: 0.3, cooldown: 0.6,
                          least_kick: 20.0,
                          kick: 40.0, most_kick: 108.0, shakes: true, fling: Throw.new(spread: 1.0, least: 0.6),
                          dead_zone: 0.2)
      CALM_TILT = TILT.with(smoothing: 0.8, shakes: false)

      # Dragging the pile (Presentation::PileGrabs): a press on a dot that
      # wanders a quarter of a radius, about a finger's wobble, or stays
      # down for 0.15 s holds it; a quicker, stiller press is a click. A
      # held dot catches up with the pointer in a few frames, and is
      # thrown at the pointer's speed over its last tenth of a second,
      # which a calm pile caps low, so a flick only nudges it.
      GRAB = GrabStyle.new(slop: 0.25, hold: 0.15, follow: 0.05, fastest: 60.0, fling: 40.0, window: 0.1)
      CALM_GRAB = GRAB.with(follow: 0.12, fastest: 20.0, fling: 6.0)

      # A worn mouse's double click (Presentation::Chatter): a press of a
      # button within 0.06 s of its last press, and within 8 units of it,
      # is dropped. A switch's bounce is under 0.02 s, and a failing one
      # chatters at 0.05 to 0.08; a hand clicking twice as fast as it can
      # takes 0.1 or more, and the fastest jitter-clicking near 0.07, so
      # no press a player makes is lost. 8 units is MouseTravel's line
      # between a jitter and a nudge: the hand on a chattering mouse has
      # not moved it.
      CHATTER = ChatterStyle.new(seconds: 0.06, reach: 8.0)

      # Sound: the pop climbs a little with the score, up to a cap. A pop
      # or a wrong tap is heard where it is across the screen, leaning at
      # most 60% to a side.
      class SoundStyle < Data.define(:pop_climb, :pop_highest, :tick_climb, :volume, :stereo); end
      SOUND = SoundStyle.new(pop_climb: 0.02, pop_highest: 1.4, tick_climb: 0.12, volume: 0.8,
                            stereo: Stereo.new(spread: 0.6))

      # A short buzz under the finger for a pop, a longer one for a wrong
      # tap, on phones and tablets that can (Shell::Haptics).
      HAPTICS = HapticsStyle.new(pop: 0.015, penalty: 0.04)

      # The gamepad cursor (Lota 0.1.3 and newer). At full tilt it crosses
      # the window corner to corner in a second, whatever the window's
      # size, and never slower than 16 R/s, nearly three times the fastest
      # dot (6 R/s), which crosses a small 24 R window in 1.5 s. It gathers
      # that speed over 0.08 s, quick enough to feel direct; the squared
      # curve leaves half a tilt at a quarter of it, for aiming. The reticle is thin and open in the
      # middle, so it never hides the dot under it.
      GAMEPAD = GamepadStyle.new(dead_zone: 0.2, curve: 2.0, speed: 16.0, crossing: 1.0, ramp: 0.08, trigger_press: 0.5,
                                trigger_release: 0.3, ring: 0.3, ticks: 0.42..0.6, line: 0.04, pip: 4)

      PATCHES = {
        # A bubbly "bloop": a sine that swoops up, with a soft click.
        pop: Patch.new(notes: [
          Note.new(wave: :sine, from: 360, to: 980, length: 0.12, volume: 1.0),
          Note.new(wave: :sine, from: 720, to: 1960, length: 0.07, volume: 0.25),
          Note.new(wave: :noise, from: 1, length: 0.012, attack: 0.001, volume: 0.25)
        ]),
        # A bonus dot appears: three bright notes up, like a bell.
        bonus: Patch.new(notes: [880.0, 1318.51, 1760.0].each_with_index.flat_map do |hz, i|
          [Note.new(wave: :sine, from: hz, start: i * 0.06, length: 0.22, volume: 0.7),
           Note.new(wave: :sine, from: hz * 2, start: i * 0.06, length: 0.14, volume: 0.18)]
        end),
        # A bonus dot is popped: the bloop, and a chord over it.
        bonus_pop: Patch.new(notes: [
          Note.new(wave: :sine, from: 360, to: 980, length: 0.12, volume: 1.0),
          Note.new(wave: :noise, from: 1, length: 0.012, attack: 0.001, volume: 0.25),
          Note.new(wave: :triangle, from: 659.25, start: 0.05, length: 0.3, volume: 0.6),
          Note.new(wave: :triangle, from: 987.77, start: 0.05, length: 0.3, volume: 0.5),
          Note.new(wave: :sine, from: 1318.51, start: 0.05, length: 0.4, volume: 0.5)
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
        new_score_record: Patch.new(notes: [523.25, 659.25, 783.99, 1046.5].each_with_index.flat_map do |hz, i|
          [Note.new(wave: :sine, from: hz, start: i * 0.08, length: 0.4, volume: 0.8),
           Note.new(wave: :sine, from: hz * 2, start: i * 0.08, length: 0.25, volume: 0.25)]
        end + [Note.new(wave: :sine, from: 2093, start: 0.34, length: 0.5, volume: 0.3)])
      }.freeze

      # The autoplay bot, for development (main.rb): how long it waits on
      # each screen, the Stats screen too, how long it thinks before each
      # tap (which grows with the score, so a game ends), and how often it
      # taps a popped dot.
      class AutopilotStyle < Data.define(:title_wait, :game_over_wait, :stats_wait, :think, :tiring, :mistakes); end
      AUTOPILOT = AutopilotStyle.new(title_wait: 1.6, game_over_wait: 3.2, stats_wait: 3.0, think: 0.22..0.45,
                                    tiring: 0.07, mistakes: 0.2)
    end
  end
end
