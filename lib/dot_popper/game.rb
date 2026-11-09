# frozen_string_literal: true

module DotPopper
  # One game: the dots, the score, and the clock. It is the one thing in
  # the rules that changes, and it changes by swapping in new values, so a
  # tap changes all three at once and says what it did with an event.
  class Game
    attr_reader :field, :dots, :score, :countdown, :elapsed, :spawns, :streak, :bonus

    # A game that goes on from where it was left before its clock first
    # ran, as the tutorial leaves it: +dots+ (a Stack) as they are, its
    # fresh dot under the rest, the +score+ they made, and +seconds+ on
    # the clock. From there it is a game like any other: its clock runs
    # from its first update, each pop spawns a dot under every dot there,
    # and a tap reaches only the topmost.
    # Its streak starts at none: the tutorial's pops were its own.
    def self.resume(field, dots:, score:, seconds:, random: Random.new, spawn_tries: Rules::SPAWN_TRIES,
                    bonus: Rules::BONUS)
      new(field, random:, dots:, score:, seconds:, spawn_tries:, bonus:)
    end

    # +spawn_tries+ is how hard a spawn works for a touch target (Spawner);
    # 0 turns the rule off, as the simulator does to measure it. +bonus+
    # (Rules::Bonus) is the streak's reward; nil turns it off, likewise.
    # +streak+ counts the pops in a row since the last wrong tap or bonus
    # dot, toward the next bonus dot.
    def initialize(field, random: Random.new, dots: nil, score: Rules::LOWEST_SCORE,
                   seconds: Rules::STARTING_SECONDS, spawn_tries: Rules::SPAWN_TRIES, bonus: Rules::BONUS)
      @field = field
      @bonus = bonus
      @streak = 0
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
      @elapsed += [seconds, countdown.remaining].min # a game plays no longer than its clock
      @countdown = countdown.tick(seconds)
    end

    # Taps the point (+x+, +y+), which reaches only the topmost dot there.
    # Returns the event that describes what happened, or nil once the
    # game is over.
    def tap_at(x, y)
      return if over?

      dot = dots.top_at(x, y)
      if dot.nil? then Events::Missed.new(x:, y:)
      elsif dot.fresh? then pop(dot, x, y)
      else penalize(dot, x, y)
      end
    end

    # Fits the game to a window that changed size, or a phone turned,
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
    def spawn(above, bonus: false)
      spawn = @spawner.spawn(@random, id: @next_id, above: above.to_a)
      spawn = spawn.with(dot: spawn.dot.with(bonus: true)) if bonus
      @next_id += 1
      @spawns << spawn
      spawn.dot
    end

    def pop(dot, x, y)
      popped = dot.pop
      above = dots.replace(popped)
      points, seconds = payoff(dot)
      earned = count_toward_bonus(dot)
      spawned = spawn(above, bonus: earned)
      @dots = above.slide_under(spawned)
      @score += points
      @countdown = countdown.adjust(seconds)
      Events::Popped.new(dot: popped, x:, y:, points:, seconds:, spawned:)
    end

    # What a pop of +dot+ pays: a pop's own, and a bonus dot's besides.
    def payoff(dot)
      rule = bonus
      return [Rules::POP_POINTS, Rules::POP_SECONDS] unless dot.bonus? && rule

      [Rules::POP_POINTS + rule.points, Rules::POP_SECONDS + rule.seconds]
    end

    # Counts the pop of +dot+ in the streak, and says whether the streak
    # is now long enough that the next fresh dot is a bonus dot. Earning
    # one, or popping one, starts the count over.
    def count_toward_bonus(dot)
      rule = bonus or return false

      @streak = dot.bonus? ? 0 : streak + 1
      earned = streak >= rule.streak
      @streak = 0 if earned
      earned
    end

    def penalize(dot, x, y)
      @streak = 0
      lost = [Rules::PENALTY_POINTS, score - Rules::LOWEST_SCORE].min
      @score -= lost
      @countdown = countdown.adjust(-Rules::PENALTY_SECONDS)
      Events::Penalized.new(dot:, x:, y:, points: -lost, seconds: -Rules::PENALTY_SECONDS)
    end
  end
end
