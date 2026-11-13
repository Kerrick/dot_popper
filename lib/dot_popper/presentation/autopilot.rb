# frozen_string_literal: true

module DotPopper
  module Presentation
    # A player for development runs (DOT_POPPER_AUTOPLAY): it goes from
    # the title to a game, taps bright dots where they show, sometimes taps
    # a popped one by mistake, slows as its score grows so the game ends,
    # and goes from Game Over back to the title. Given the Show, it presses
    # the buttons a player would: Play to start a game, Home to go
    # back, "Share my score" on every other Game Over, then Copy in the
    # share preview, and Close, a moment apart (on a phone, the system's
    # share sheet opens instead, and the bot goes on), and on its second visit to
    # the title, "Your stats", and Back after a while. The first time the title offers
    # the choice of dot size, it taps the other one, so a run shows the
    # title's dots change. It sees only what a player sees: the dots and
    # the screen.
    class Autopilot
      # Where it looks for an uncovered part of the bright dot: its center,
      # then points around it, in radii.
      PROBES = [[0, 0]] + (0...8).map { [0.6 * Math.cos(it * Math::PI / 4), 0.6 * Math.sin(it * Math::PI / 4)] }

      def initialize(style, random: Random.new(7))
        @style = style
        @random = random
        @state = nil
        @waited = 0.0
        @cooldown = 0.0
        @game_overs = 0
        @titles = 0
        @browsed = false
        @resized = false
        @shared = false
        @pressed_at = 0.0
      end

      # Where to press this frame, as [x, y], or nil.
      def update(seconds, cabinet, show = nil)
        notice(cabinet.state)
        @waited += seconds
        case cabinet.state
        when Cabinet::Home then title(cabinet, show)
        when Cabinet::GameOver then finish(cabinet, show)
        when Cabinet::Playing then play(seconds, cabinet.game)
        end
      end

      private

      def notice(state)
        return if state.class == @state

        @game_overs += 1 if state.is_a?(Cabinet::GameOver)
        @titles += 1 if state.is_a?(Cabinet::Home)
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

      def title(cabinet, show)
        return later_on_arrival(show) if show&.arrival?
        return browse(show) if show && (show.stats? || (@titles == 2 && !@browsed))
        return choose_size(show) if show && (show.settings? || (!@resized && @browsed && show.sizing_offered?))

        press_once(@style.title_wait) { start(cabinet, show) }
      end

      # A new theme's card, as DOT_POPPER_THEME_UNLOCKS shows it: Play is out
      # of reach (Show#controls) until it is answered, so the bot says "Not now".
      def later_on_arrival(show)
        return if @waited < @style.title_wait / 2

        @waited = 0.0
        middle(show.reach_of(:arrival_later))
      end

      # Opens "Your stats" once it is offered, and presses Back after
      # +records_wait+; the title's own wait then starts again.
      def browse(show)
        if show.stats?
          return if @waited < @style.stats_wait

          @waited = 0.0
          return middle(show.back_reach)
        end
        return unless show.stats_offered? && @waited >= @style.title_wait / 2

        @browsed = true
        @waited = 0.0
        middle(show.stats_reach)
      end

      # Opens Settings once Home offers the choice of dot size, taps the
      # size not yet chosen, and presses Back after +stats_wait+; Home's
      # own wait then starts again.
      def choose_size(show)
        if show.settings?
          return if @waited < @style.title_wait / 2
          return middle(show.back_reach) if @resized && @waited >= @style.stats_wait

          return if @resized

          @resized = true
          other = Show::SIZINGS.find { it != show.cabinet.sizing }
          return middle(show.reach_of(other) || show.back_reach)
        end
        return if @waited < @style.title_wait / 2

        @waited = 0.0
        middle(show.reach_of(:settings))
      end

      # Play's middle; without the Show, the middle of the screen, which
      # the game itself takes as a start.
      def start(cabinet, show) = show ? middle(show.play_reach) : center(cabinet.field)

      # Shares and copies every other result first, then presses Home
      # once the game will hear.
      def finish(cabinet, show)
        return in_preview(show) if show&.sharing?

        if show && @game_overs.even? && !@shared && @waited >= @style.game_over_wait / 2 && show.share_reach
          @shared = true
          @pressed_at = @waited
          return middle(show.share_reach)
        end
        press_once(@style.game_over_wait) { show ? middle(show.home_reach) : center(cabinet.field) } if cabinet.state.ready?
      end

      # In the share preview, a moment after each press: Copy, then Close.
      def in_preview(show)
        return if @waited - @pressed_at < @style.game_over_wait / 4

        @pressed_at = @waited
        middle(show.share_preview.copied? ? show.close_reach : show.copy_reach)
      end

      def middle(rect) = [rect.center_x, rect.center_y]

      def play(seconds, game)
        @cooldown -= seconds
        return if @cooldown.positive?

        target = (mistake(game) if @random.rand < @style.mistakes) || exposed_bright(game)
        @cooldown = target ? @random.rand(@style.think) + (@style.tiring * game.score) : 0.05
        target
      end

      # A point on the bright dot where a popped one lies over it, or nil.
      def covered_bright(game)
        bright = game.dots.find(&:bright?)
        return unless bright

        probes(bright).find { |x, y| game.dots.top_at(x, y)&.popped? }
      end

      def probes(dot) = PROBES.lazy.map { |dx, dy| [dot.x + (dx * dot.radius), dot.y + (dy * dot.radius)] }

      def exposed_bright(game)
        bright = game.dots.find(&:bright?)
        return unless bright

        probes(bright).find { |x, y| game.dots.top_at(x, y)&.id == bright.id }
      end

      # A player's usual mistake is impatience: tapping the bright dot
      # before it has come out. Failing that, any popped dot in view.
      def mistake(game)
        hidden = covered_bright(game)
        return hidden if hidden

        popped = game.dots.select { |dot| dot.popped? && game.dots.top_at(dot.x, dot.y)&.id == dot.id }
        dot = popped.sample(random: @random)
        dot && [dot.x, dot.y]
      end
    end
  end
end
