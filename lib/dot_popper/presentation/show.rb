# frozen_string_literal: true

module DotPopper
  module Presentation
    # Everything the player sees and hears that is not a rule. The Show
    # listens to the rules' events and cues the effects, the dots'
    # animations, the HUD, and the sounds; it hands every tap straight to
    # the game on the frame it happens, and keeps the time that all its
    # animations play against. A renderer draws from it; it draws nothing
    # itself.
    #
    # +sounds+ answers play(name, pitch:, pan:), muted?, and toggle_mute;
    # +haptics+ answers buzz(seconds). +lifetime+ (Lifetime) adds up every
    # round the device has played. +sizing_store+ keeps the player's
    # DotSizing, chosen on the title. +radius+ is the usual dot's, which
    # sizes the buttons' reach; a round's effects follow its own dots.
    class Show
      # The dot-size choices in the order the title draws their segments.
      SIZINGS = [DotSizing::SAME_EVERYWHERE, DotSizing::SIZED_TO_SCREEN].freeze

      attr_reader :game, :effects, :animations, :hud, :attract, :layout, :marquee, :finale, :sounds, :now, :look,
                  :lifetime

      def initialize(game:, layout:, sounds:, radius:, look: Look, random: Random.new, calm: false,
                     tutor: Tutor.new(BestScore::Memory.new, times: look::LESSON.times), haptics: NoHaptics.new, clipboard: MemoryClipboard.new,
                     lifetime: Lifetime.new(BestScore::Memory.new), sizing_store: BestScore::Memory.new)
        @game = game
        @lifetime = lifetime
        @layout = layout
        @sounds = sounds
        @haptics = haptics
        @radius = radius
        @scale = radius
        @sizing_store = sizing_store
        @look = look
        @random = random
        @effects = Effects.new(radius:, random:, calm:)
        @animations = DotAnimations.new(look::MOTION)
        @hud = Hud.blank(look::HUD, look::WORDS)
        @attract = Attract.spawn(game.field, look::TITLE)
        @now = 0.0
        @marquee = Marquee.new(look: look::TITLE, best: game.best.of(game.size_class), at: @now)
        @finale = nil
        @tutor = tutor
        @clipboard = clipboard
        @hid_fresh = false
        @penalized_at = -Float::INFINITY
        @recorder = RoundStats::Recorder.new
        @records = nil
        game.subscribe(@recorder)
        game.subscribe(self)
      end

      # The numbers of the round in play, or of the one just finished.
      def stats = @recorder.stats

      def palette = look::PALETTE
      def words = look::WORDS

      def title? = game.state.is_a?(Game::Title)

      # Whether the Records screen is open over the title. It is the
      # presentation's alone: the game stays on its title meanwhile, and
      # no tap there reaches the game.
      def records? = !@records.nil?

      # What the Records screen shows, while it is open.
      def records = @records

      # Whether the title offers "Your records" and today's goal: only once
      # a round has finished, so a first-time player's title says only how
      # to play.
      def records_offered? = lifetime.stats.rounds.positive?
      def playing? = game.state.is_a?(Game::Playing)
      def finished? = game.state.is_a?(Game::GameOver)

      # A tap anywhere. On the title, the mute button, "Your records", and
      # the dot-size choice take their own taps, as "Copy my result" does on Game Over, and on
      # the Records screen a tap anywhere goes back; every other tap goes
      # to the game at once. A tap on one of the title's fresh dots also
      # pops it, as the round starts.
      def tap(x, y)
        if records? then close_records
        elsif title? && layout.mute_button.contains?(x, y) then sounds.toggle_mute
        elsif title? && records_offered? && records_reach.contains?(x, y) then open_records
        elsif title? && records_offered? && (sizing = sizing_at(x, y)) then choose_sizing(sizing)
        elsif finished? && share_reach.contains?(x, y) then share
        else
          scenery = attract.dots.top_at(x, y) if title?
          game.press(x, y)
          toy_pop(scenery, x, y) if scenery&.fresh?
        end
      end

      # A gamepad's Start: on the title it starts the usual round, and
      # after one it continues, as a tap on empty space would, grace and
      # all; where it presses does not matter on either screen. In a round
      # it does nothing, since only a press at a place may touch the score.
      def start
        return close_records if records?

        game.press(layout.center_x, layout.center_y) unless playing?
      end

      # Escape, or a gamepad's B: leaves the Records screen. Says whether
      # there was one to leave, so that elsewhere the key can do its usual
      # job.
      def back
        return false unless records?

        close_records
        true
      end

      # Switches how dots are sized (DotSizing) to the other choice, as a
      # gamepad's shoulder button does.
      def toggle_sizing = choose_sizing(game.sizing.toggled)

      # Sizes dots as +sizing+ (DotSizing) says, on the title once it
      # offers the choice, and remembers it. The title's dots and best
      # change with it, so the choice shows at once.
      def choose_sizing(sizing)
        return unless title? && records_offered?
        return sounds.play(:tick, pitch: 0.8) if sizing == game.sizing

        game.sizing = sizing
        @sizing_store.write(game.sizing.to_text)
        @attract = Attract.spawn(game.field, look::TITLE)
        @marquee = marquee.with(best: game.best.of(game.size_class))
        sounds.play(:tick, pitch: game.sizing.sized_to_screen? ? 1.2 : 0.9)
      end

      # Opens the Records screen over the title, with the stats as they
      # are now.
      def open_records
        return unless title?

        size_class = game.size_class
        @records = RecordsSheet.build(lifetime.stats, best: game.best.of(size_class), words:, streak: lifetime.streak,
                                      size_class:, field: game.field, sizing: game.sizing)
        sounds.play(:tick)
      end

      def close_records
        @records = nil
        sounds.play(:tick, pitch: 0.8)
      end

      # A gamepad's Y, or a tap on "Copy my result": on Game Over, copies
      # the round's result to share. Anywhere else it does nothing.
      def share
        return unless finished? && finale

        @clipboard.copy(words.share_text(finale.score, finale.stats, best: finale.best, new_best: finale.new_best?,
                                         record: finale.record, screen: finale.screen))
        @finale = finale.copy(now)
        sounds.play(:tick)
      end

      # Where a tap reaches "Copy my result": never less than a dot's width.
      def share_reach = layout.share_button.reach(2 * @radius)

      # Where a tap reaches "Your records": never less than a dot's width,
      # and never past the safe area's bottom.
      def records_reach = within_safe(layout.records_button.reach(2 * @radius))

      # Where a tap reaches each segment of the dot-size choice, as a
      # DotSizing and its Rect: never less than a dot's width, and never
      # past the safe area's bottom.
      def sizing_reaches = SIZINGS.zip(layout.sizing_control.options.map { within_safe(it.reach(2 * @radius)) })

      # The window changed size. The title's dots are respawned if their
      # size changes with it, as dots sized to the screen do.
      def resize(layout, field)
        @layout = layout
        @attract = field.radius == attract.field.radius ? attract.refit(field) : Attract.spawn(field, look::TITLE)
      end

      def update(seconds)
        @now += seconds
        effects.update(seconds)
        @attract = attract.update(seconds) if title?
        @hud = hud.read(game.round, now) { tick(it) if playing? } if game.round
        follow_finale if finished?
      end

      # Hears one of the rules' events (Game#subscribe).
      def call(event)
        case event
        when Events::RoundStarted then round_started(event)
        when Events::Popped then popped(event)
        when Events::Penalized then penalized(event)
        when Events::Missed then effects.ring(event.x, event.y, look::TOUCH_RIPPLE)
        when Events::RoundEnded then round_ended(event)
        when Events::TitleShown then title_shown(event)
        end
      end

      private

      # The dot-size choice whose segment a tap at +x+, +y+ reaches, or nil.
      def sizing_at(x, y) = sizing_reaches.find { |_, reach| reach.contains?(x, y) }&.first

      def within_safe(reach) = reach.with(height: [reach.height, layout.safe.bottom - reach.y].min)

      def round_started(event)
        @scale = event.round.field.radius
        effects.clear
        effects.scale_to(@scale)
        animations.clear
        @hud = Hud.blank(look::HUD, look::WORDS)
        event.round.dots.each { animations.spawn(it.id, now) }
        @finale = nil
        @hid_fresh = false
        sounds.play(:start)
      end

      def popped(event)
        dot = event.dot
        animations.pop(dot.id, now)
        animations.spawn(event.spawned.id, now)
        effects.burst(event.x, event.y, look::POP_BURST, palette.confetti)
        effects.ring(dot.x, dot.y, look::SHOCKWAVE, follow: dot.id)
        effects.ring(event.spawned.x, event.spawned.y, look::SPAWN_RIPPLE, follow: event.spawned.id)
        float_pair(event.x, event.y, Words.points(event.points), Words.seconds(event.seconds),
                   palette.cream, palette.gain, look::GAIN_FLOAT)
        sounds.play(:pop, pitch: pop_pitch, pan: pan(event.x))
        @haptics.buzz(look::HAPTICS.pop)
      end

      def penalized(event)
        @penalized_at = now
        animations.wobble(event.dot.id, now)
        effects.ring(event.dot.x, event.dot.y, look::ALARM_RING, follow: event.dot.id)
        hidden = game.round.dots.fresh_beneath(event.dot, event.x, event.y)
        effects.reveal(hidden, look::REVEAL) if hidden
        @hid_fresh ||= !hidden.nil?
        effects.kick(look::PENALTY_SHAKE)
        effects.light(look::PENALTY_FLASH)
        # The floor can keep the score from falling; say only what was lost.
        points = event.points.zero? ? nil : Words.points(event.points)
        float_pair(event.x, event.y, points, Words.seconds(event.seconds), palette.alarm, palette.alarm,
                   look::LOSS_FLOAT)
        sounds.play(:bonk, pan: pan(event.x))
        @haptics.buzz(look::HAPTICS.penalty)
      end

      def round_ended(event)
        result = lifetime.record(stats, event.size_class)
        lesson = @tutor.lesson(words.covered) if @hid_fresh
        @finale = Finale.new(look: look::FINALE, score: event.score, best: event.best, new_best: event.new_best, at: now,
                             stats:, record: result.records.first, goal_met: result.goal_met, lesson:,
                             screen: words.played_on(event.round.field, sized: event.size_class == SizeClass::FITTED))
        sounds.play(event.new_best ? :new_best : :game_over)
      end

      def title_shown(event)
        @records = nil
        effects.clear
        @finale = nil
        @marquee = Marquee.new(look: look::TITLE, best: event.best, at: now)
      end

      # The title's dot, popped by the tap that started the round: its
      # droplets, its ring, and its bloop, but no score.
      def toy_pop(dot, x, y)
        effects.burst(x, y, look::POP_BURST, palette.confetti)
        effects.ring(dot.x, dot.y, look::SHOCKWAVE)
        sounds.play(:pop, pan: pan(x))
      end

      # One floater to the left and one to the right of the tap; with only
      # one, it sits over the tap.
      def float_pair(x, y, left, right, left_color, right_color, float)
        spread = look::FLOAT_SPREAD * @scale
        spread = 0.0 unless left && right
        effects.float(left, x - spread, y, left_color, float) if left
        effects.float(right, x + spread, y, right_color, float) if right
      end

      # Where across the stereo field a sound at +x+ plays.
      def pan(x) = look::SOUND.stereo.pan(x, layout.width)

      def pop_pitch
        sound = look::SOUND
        [1.0 + (game.round.score * sound.pop_climb), sound.pop_highest].min
      end

      def tick(seconds)
        return if now - @penalized_at < 0.1

        sounds.play(:tick, pitch: 1.0 + ((look::HUD.urgent_below - seconds) * look::SOUND.tick_climb))
        effects.light(look::TICK_FLASH)
      end

      def follow_finale
        @finale = finale.ready(now) if game.state.ready?
        goal_burst if finale.goal_due?(now)
        return unless finale.celebration_due?(now)

        @finale = finale.celebrate
        celebrate
      end

      # A small burst of twinkles where "You met today's goal!" appears.
      def goal_burst
        @finale = finale.goal_celebrate
        effects.burst(layout.center_x, layout.finale_goal_y, look::FINALE.goal_sparkles, palette.confetti,
                      longest: look::FINALE.sparkle_life)
        sounds.play(:tick, pitch: 1.5)
      end

      def celebrate
        sparkles = look::FINALE.sparkles
        [0.3, 0.5, 0.7].each do |across|
          effects.burst(layout.safe.x + (layout.safe.width * across), layout.top + (layout.safe.height * 0.2),
                        sparkles, palette.confetti, longest: look::FINALE.sparkle_life)
        end
      end
    end
  end
end
