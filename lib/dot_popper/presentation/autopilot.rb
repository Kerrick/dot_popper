# frozen_string_literal: true

module DotPopper
  module Presentation
    # A player for development runs (DOT_POPPER_AUTOPLAY): it goes from
    # the title to a round, taps fresh dots where they show, sometimes taps
    # a popped one by mistake, slows as its score grows so the round ends,
    # and goes from Game Over back to the title. Given the Show, it presses
    # the buttons a player would: Play to start a round, Continue to go
    # on, "Share my score" on every other Game Over, then Copy in the
    # share preview, and Close, a moment apart (on a phone, the system's
    # share sheet opens instead, and the bot goes on), and on its second visit to
    # the title, "Your records", and Back after a while. The first time the title offers
    # the choice of dot size, it taps the other one, so a run shows the
    # title's dots change. It sees only what a player sees: the dots and
    # the screen.
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
        @finales = 0
        @titles = 0
        @browsed = false
        @resized = false
        @shared = false
        @pressed_at = 0.0
      end

      # Where to press this frame, as [x, y], or nil.
      def update(seconds, game, show = nil)
        notice(game.state)
        @waited += seconds
        case game.state
        when Game::Title then title(game, show)
        when Game::GameOver then finish(game, show)
        when Game::Playing then play(seconds, game.round)
        end
      end

      private

      def notice(state)
        return if state.class == @state

        @finales += 1 if state.is_a?(Game::GameOver)
        @titles += 1 if state.is_a?(Game::Title)
        @shared = false
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

      def title(game, show)
        return browse(show) if show && (show.records? || (@titles == 2 && !@browsed))
        return choose_size(show) if show && !@resized && show.sizing_offered?

        press_once(@look.title_wait) { start(game, show) }
      end

      # Taps the choice of dot size not yet chosen, once, after half the
      # title's wait; the title's own wait then starts again.
      def choose_size(show)
        return if @waited < @look.title_wait / 2

        @resized = true
        @waited = 0.0
        middle(show.sizing_reaches.reject { |sizing, _| sizing == show.game.sizing }.first.last)
      end

      # Opens "Your records" once it is offered, and presses Back after
      # +records_wait+; the title's own wait then starts again.
      def browse(show)
        if show.records?
          return if @waited < @look.records_wait

          @waited = 0.0
          return middle(show.back_reach)
        end
        return unless show.records_offered? && @waited >= @look.title_wait / 2

        @browsed = true
        @waited = 0.0
        middle(show.records_reach)
      end

      # Play's middle; without the Show, the middle of the screen, which
      # the game itself takes as a start.
      def start(game, show) = show ? middle(show.play_reach) : center(game.field)

      # Shares and copies every other result first, then presses Continue
      # once the game will hear.
      def finish(game, show)
        return in_preview(show) if show&.sharing?

        if show && @finales.even? && !@shared && @waited >= @look.finale_wait / 2 && show.share_reach
          @shared = true
          @pressed_at = @waited
          return middle(show.share_reach)
        end
        press_once(@look.finale_wait) { show ? middle(show.continue_reach) : center(game.field) } if game.state.ready?
      end

      # In the share preview, a moment after each press: Copy, then Close.
      def in_preview(show)
        return if @waited - @pressed_at < @look.finale_wait / 4

        @pressed_at = @waited
        middle(show.share_preview.copied? ? show.close_reach : show.copy_reach)
      end

      def middle(rect) = [rect.center_x, rect.center_y]

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
