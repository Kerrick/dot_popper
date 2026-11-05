# frozen_string_literal: true

module DotPopper
  # One round: the dots, the score, and the clock. Taps change all three
  # at once and say what they did by returning an event.
  class Round
    attr_reader :field, :dots, :score, :countdown

    def initialize(field, random: Random.new)
      @field = field
      @random = random
      @dots = Stack.new
      @score = 0
      @countdown = Countdown.new(Rules::STARTING_SECONDS)
      spawn
    end

    def over? = countdown.expired?

    def update(seconds)
      return if over?

      dots.each { |dot| dot.move(seconds, field) }
      countdown.tick(seconds)
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
      dots.each { |dot| dot.confine(field) }
    end

    private

    def spawn = dots.slide_under(Dot.spawn(field, @random))

    def pop(dot, x, y)
      dot.pop
      @score += Rules::POP_POINTS
      countdown.adjust(Rules::POP_SECONDS)
      Events::Popped.new(dot:, x:, y:, points: Rules::POP_POINTS, seconds: Rules::POP_SECONDS, spawned: spawn)
    end

    def penalize(dot, x, y)
      lost = [Rules::PENALTY_POINTS, score - Rules::LOWEST_SCORE].min
      @score -= lost
      countdown.adjust(-Rules::PENALTY_SECONDS)
      Events::Penalized.new(dot:, x:, y:, points: -lost, seconds: -Rules::PENALTY_SECONDS)
    end
  end
end
