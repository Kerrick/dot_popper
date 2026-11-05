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
    # +sounds+ answers play(name, pitch:, pan:), muted?, and toggle_mute.
    class Show
      attr_reader :game, :effects, :animations, :hud, :attract, :layout, :marquee, :finale, :sounds, :now, :look

      def initialize(game:, layout:, sounds:, radius:, look: Look, random: Random.new, calm: false)
        @game = game
        @layout = layout
        @sounds = sounds
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
        @penalized_at = -Float::INFINITY
        game.subscribe(self)
      end

      def palette = look::PALETTE
      def words = look::WORDS

      def title? = game.state.is_a?(Game::Title)
      def playing? = game.state.is_a?(Game::Playing)
      def finished? = game.state.is_a?(Game::GameOver)

      # A tap anywhere. On the title, the mute button takes its own taps;
      # every other tap goes to the game at once.
      def tap(x, y)
        if title? && layout.mute_button.contains?(x, y)
          sounds.toggle_mute
        else
          game.press(x, y)
        end
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
      end

      def penalized(event)
        @penalized_at = now
        animations.wobble(event.dot.id, now)
        effects.ring(event.dot.x, event.dot.y, look::ALARM_RING, follow: event.dot.id)
        effects.kick(look::PENALTY_SHAKE)
        effects.light(look::PENALTY_FLASH)
        # The floor can keep the score from falling; say only what was lost.
        points = event.points.zero? ? nil : Words.points(event.points)
        float_pair(event.x, event.y, points, Words.seconds(event.seconds), palette.alarm, palette.alarm,
                   look::LOSS_FLOAT)
        sounds.play(:bonk, pan: pan(event.x))
      end

      def round_ended(event)
        @finale = Finale.new(look: look::FINALE, score: event.score, best: event.best, new_best: event.new_best, at: now)
        sounds.play(event.new_best ? :new_best : :game_over)
      end

      def title_shown(event)
        effects.clear
        @finale = nil
        @marquee = Marquee.new(look: look::TITLE, best: event.best, at: now)
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
        return unless finale.celebration_due?(now)

        @finale = finale.celebrate
        celebrate
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
