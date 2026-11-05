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
    # round the device has played.
    class Show
      attr_reader :game, :effects, :animations, :hud, :hint, :attract, :layout, :marquee, :finale, :sounds, :now, :look,
                  :lifetime

      def initialize(game:, layout:, sounds:, radius:, look: Look, random: Random.new, calm: false,
                     tutor: Tutor.new(BestScore::Memory.new), haptics: NoHaptics.new, clipboard: MemoryClipboard.new,
                     lifetime: Lifetime.new(BestScore::Memory.new))
        @game = game
        @lifetime = lifetime
        @layout = layout
        @sounds = sounds
        @haptics = haptics
        @radius = radius
        @look = look
        @random = random
        @effects = Effects.new(radius:, random:, calm:)
        @animations = DotAnimations.new(look::MOTION)
        @hud = Hud.blank(look::HUD, look::WORDS)
        @attract = Attract.spawn(game.field, look::TITLE)
        @now = 0.0
        @marquee = Marquee.new(look: look::TITLE, best: game.best.value, at: @now)
        @finale = nil
        @tutor = tutor
        @clipboard = clipboard
        @hint = nil
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

      # A tap anywhere. On the title, the mute button and "Your records"
      # take their own taps, as "Copy my result" does on Game Over, and on
      # the Records screen a tap anywhere goes back; every other tap goes
      # to the game at once. A tap on one of the title's fresh dots also
      # pops it, as the round starts.
      def tap(x, y)
        if records? then close_records
        elsif title? && layout.mute_button.contains?(x, y) then sounds.toggle_mute
        elsif title? && records_offered? && records_reach.contains?(x, y) then open_records
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

      # Opens the Records screen over the title, with the stats as they
      # are now.
      def open_records
        return unless title?

        @records = RecordsSheet.build(lifetime.stats, best: game.best.value, words:, streak: lifetime.streak)
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
                                         record: finale.record))
        @finale = finale.copy(now)
        sounds.play(:tick)
      end

      # Where a tap reaches "Copy my result": never less than a dot's width.
      def share_reach = layout.share_button.reach(2 * @radius)

      # Where a tap reaches "Your records": never less than a dot's width,
      # and never past the safe area's bottom.
      def records_reach
        reach = layout.records_button.reach(2 * @radius)
        reach.with(height: [reach.height, layout.safe.bottom - reach.y].min)
      end

      def resize(layout, field)
        @layout = layout
        @attract = attract.refit(field)
      end

      def update(seconds)
        @now += seconds
        effects.update(seconds)
        @attract = attract.update(seconds) if title?
        @hud = hud.read(game.round, now) { tick(it) if playing? } if game.round
        @hint = nil unless hint&.alive?(now) && playing?
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

      def round_started(event)
        effects.clear
        animations.clear
        @hud = Hud.blank(look::HUD, look::WORDS)
        event.round.dots.each { animations.spawn(it.id, now) }
        @finale = nil
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
        @hint = @tutor.slipped(words.covered, look::HINT, now) || hint
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
        result = lifetime.record(stats)
        @finale = Finale.new(look: look::FINALE, score: event.score, best: event.best, new_best: event.new_best, at: now,
                             stats:, record: result.records.first, goal_met: result.goal_met)
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
        spread = look::FLOAT_SPREAD * @radius
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
