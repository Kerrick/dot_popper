# frozen_string_literal: true

module DotPopper
  # One round: the dots, the score, and the clock. It is the one thing in
  # the rules that changes, and it changes by swapping in new values, so a
  # tap changes all three at once and says what it did with an event.
  class Round
    attr_reader :field, :dots, :score, :countdown

    def initialize(field, random: Random.new, dots: nil)
      @field = field
      @random = random
      @next_id = 0
      @score = 0
      @countdown = Countdown.new(remaining: Rules::STARTING_SECONDS)
      @dots = dots || Stack.new.slide_under(spawn)
      @next_id = @dots.map(&:id).max.to_i + 1
    end

    def over? = countdown.expired?

    def update(seconds)
      return if over?

      @dots = dots.map_dots { it.move(seconds, field) }
      @countdown = countdown.tick(seconds)
    end

    # Taps the point (+x+, +y+), which reaches only the topmost dot there.
    # Returns the event that describes what happened, or nil once the
    # round is over.
    def tap_at(x, y)
      return if over?

      dot = dots.top_at(x, y)
      if dot.nil? then Events::Missed.new(x:, y:)
      elsif dot.fresh? then pop(dot, x, y)
      else penalize(dot, x, y)
      end
    end

    # Fits the round to a window that changed size, keeping every dot on
    # screen.
    def field=(field)
      @field = field
      @dots = dots.map_dots { it.confine(field) }
    end

    private

    def spawn
      Dot.spawn(field, @random, id: @next_id).tap { @next_id += 1 }
    end

    def pop(dot, x, y)
      popped = dot.pop
      spawned = spawn
      @dots = dots.replace(popped).slide_under(spawned)
      @score += Rules::POP_POINTS
      @countdown = countdown.adjust(Rules::POP_SECONDS)
      Events::Popped.new(dot: popped, x:, y:, points: Rules::POP_POINTS, seconds: Rules::POP_SECONDS, spawned:)
    end

    def penalize(dot, x, y)
      lost = [Rules::PENALTY_POINTS, score - Rules::LOWEST_SCORE].min
      @score -= lost
      @countdown = countdown.adjust(-Rules::PENALTY_SECONDS)
      Events::Penalized.new(dot:, x:, y:, points: -lost, seconds: -Rules::PENALTY_SECONDS)
    end
  end
end
