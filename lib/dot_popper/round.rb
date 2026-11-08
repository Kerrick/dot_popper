# frozen_string_literal: true

module DotPopper
  # One round: the dots, the score, and the clock. It is the one thing in
  # the rules that changes, and it changes by swapping in new values, so a
  # tap changes all three at once and says what it did with an event.
  class Round
    attr_reader :field, :dots, :score, :countdown, :elapsed, :spawns

    # A round that goes on from where it was left before its clock first
    # ran, as the tutorial leaves it: +dots+ (a Stack) as they are, its
    # fresh dot under the rest, the +score+ they made, and +seconds+ on
    # the clock. From there it is a round like any other: its clock runs
    # from its first update, each pop spawns a dot under every dot there,
    # and a tap reaches only the topmost.
    def self.resume(field, dots:, score:, seconds:, random: Random.new, spawn_tries: Rules::SPAWN_TRIES)
      new(field, random:, dots:, score:, seconds:, spawn_tries:)
    end

    # +spawn_tries+ is how hard a spawn works for a touch target (Spawner);
    # 0 turns the rule off, as the simulator does to measure it.
    def initialize(field, random: Random.new, dots: nil, score: Rules::LOWEST_SCORE,
                   seconds: Rules::STARTING_SECONDS, spawn_tries: Rules::SPAWN_TRIES)
      @field = field
      @random = random
      @spawner = Spawner.for(field, tries: spawn_tries)
      @spawns = []
      @next_id = 0
      @score = score
      @elapsed = 0.0
      @countdown = Countdown.new(remaining: seconds)
      @dots = dots || Stack.new.slide_under(spawn(Stack.new))
      @next_id = @dots.map(&:id).max.to_i + 1
    end

    def over? = countdown.expired?

    def update(seconds)
      return if over?

      @dots = dots.map_dots { it.move(seconds, field) }
      @elapsed += [seconds, countdown.remaining].min # a round plays no longer than its clock
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

    # Fits the round to a window that changed size, or a phone turned,
    # keeping every dot where it was in proportion (Dot#refit), and so on
    # screen.
    def field=(field)
      old = @field
      @field = field
      @spawner = Spawner.for(field, tries: @spawner.tries)
      @dots = dots.map_dots { it.refit(old, field) }
    end

    private

    # A fresh dot to go in beneath every dot of +above+, recorded in
    # +spawns+.
    def spawn(above)
      spawn = @spawner.spawn(@random, id: @next_id, above: above.to_a)
      @next_id += 1
      @spawns << spawn
      spawn.dot
    end

    def pop(dot, x, y)
      popped = dot.pop
      above = dots.replace(popped)
      spawned = spawn(above)
      @dots = above.slide_under(spawned)
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
