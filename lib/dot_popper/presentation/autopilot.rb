# frozen_string_literal: true

module DotPopper
  module Presentation
    # A player for development runs (DOT_POPPER_AUTOPLAY): it goes from
    # the title to a round, taps fresh dots where they show, sometimes taps
    # a popped one by mistake, slows as its score grows so the round ends,
    # and taps through game over back to the title. It sees only what a
    # player sees: the dots and the screen.
    class Autopilot
      # Where it looks for an uncovered part of the fresh dot: its centre,
      # then points around it, in radii.
      PROBES = [[0, 0]] + (0...8).map { [0.6 * Math.cos(it * Math::PI / 4), 0.6 * Math.sin(it * Math::PI / 4)] }

      def initialize(look, random: Random.new(7))
        @look = look
        @random = random
        @state = nil
        @waited = 0.0
        @cooldown = 0.0
      end

      # Where to press this frame, as [x, y], or nil.
      def update(seconds, game)
        notice(game.state)
        @waited += seconds
        case game.state
        when Game::Title then press_once(@look.title_wait) { center(game.field) }
        when Game::GameOver then press_once(@look.finale_wait) { center(game.field) } if game.state.ready?
        when Game::Playing then play(seconds, game.round)
        end
      end

      private

      def notice(state)
        return if state.class == @state

        @state = state.class
        @waited = 0.0
        @cooldown = 0.4
      end

      def press_once(wait)
        return if @waited < wait

        @waited = -Float::INFINITY
        yield
      end

      def center(field) = [field.width / 2.0, field.height * 0.62]

      def play(seconds, round)
        @cooldown -= seconds
        return if @cooldown.positive?

        target = (mistake(round) if @random.rand < @look.mistakes) || exposed_fresh(round)
        @cooldown = target ? @random.rand(@look.think) + (@look.tiring * round.score) : 0.05
        target
      end

      # A point on the fresh dot where a popped one lies over it, or nil.
      def covered_fresh(round)
        fresh = round.dots.find(&:fresh?)
        return unless fresh

        probes(fresh).find { |x, y| round.dots.top_at(x, y)&.popped? }
      end

      def probes(dot) = PROBES.lazy.map { |dx, dy| [dot.x + (dx * dot.radius), dot.y + (dy * dot.radius)] }

      def exposed_fresh(round)
        fresh = round.dots.find(&:fresh?)
        return unless fresh

        probes(fresh).find { |x, y| round.dots.top_at(x, y)&.id == fresh.id }
      end

      # A player's usual mistake is impatience: tapping the fresh dot
      # before it has come out. Failing that, any popped dot in view.
      def mistake(round)
        hidden = covered_fresh(round)
        return hidden if hidden

        popped = round.dots.select { |dot| dot.popped? && round.dots.top_at(dot.x, dot.y)&.id == dot.id }
        dot = popped.sample(random: @random)
        dot && [dot.x, dot.y]
      end
    end
  end
end
