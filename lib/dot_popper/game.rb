# frozen_string_literal: true

module DotPopper
  # One game: the dots, the score, and the clock. It is the one thing in
  # the rules that changes, and it changes by swapping in new values, so a
  # tap changes all three at once and says what it did with an event.
  class Game
    attr_reader :field, :dots, :score, :countdown, :elapsed, :spawns, :dots_in_a_row, :bonus

    # +dots+ (a Stack), when given, are its first dots, in place of the
    # one it would spawn, as the tutorial places its first. +spawn_tries+
    # is how hard a spawn works for a touch target (Spawner); 0 turns the
    # rule off, as the simulator does to measure it. +bonus+
    # (Rules::Bonus) is the row's reward; nil turns it off, likewise.
    # +dots_in_a_row+ counts the dots in a row since the last mistake or
    # bonus dot, toward the next bonus dot.
    def initialize(field, random: Random.new, dots: nil, spawn_tries: Rules::SPAWN_TRIES, bonus: Rules::BONUS)
      @field = field
      @bonus = bonus
      @dots_in_a_row = 0
      @random = random
      @spawner = Spawner.for(field, tries: spawn_tries)
      @spawns = []
      @next_id = 0
      @score = Rules::LOWEST_SCORE
      @elapsed = 0.0
      @countdown = Countdown.new(remaining: Rules::STARTING_SECONDS)
      @dots = dots || Stack.new.slide_under(spawn(Stack.new))
      @next_id = @dots.map(&:id).max.to_i + 1
    end

    def over? = countdown.expired?

    def update(seconds)
      return if over?

      move_dots(seconds)
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

    # Moves the dots +seconds+ on, and only the dots: the clock does not
    # run. A paused game's tutorial moves them at its own pace
    # (Cabinet::Paused).
    def move_dots(seconds)
      @dots = dots.map_dots { it.move(seconds, field) }
    end

    # Puts each of +placed+ in the place of the dot of its id, where it
    # is and going as it goes, at the same depth in the stack. Only a
    # paused game's tutorial arranges its dots, to show them as it
    # teaches (Cabinet#arrange).
    def arrange(*placed)
      @dots = placed.reduce(dots) { |stack, dot| stack.replace(dot) }
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

    # Counts the pop of +dot+ in the row, and says whether the row
    # is now long enough that the next fresh dot is a bonus dot. Earning
    # one, or popping one, starts the count over.
    def count_toward_bonus(dot)
      rule = bonus or return false

      @dots_in_a_row = dot.bonus? ? 0 : dots_in_a_row + 1
      earned = dots_in_a_row >= rule.dots_in_a_row
      @dots_in_a_row = 0 if earned
      earned
    end

    def penalize(dot, x, y)
      @dots_in_a_row = 0
      lost = [Rules::PENALTY_POINTS, score - Rules::LOWEST_SCORE].min
      @score -= lost
      @countdown = countdown.adjust(-Rules::PENALTY_SECONDS)
      Events::Penalized.new(dot:, x:, y:, points: -lost, seconds: -Rules::PENALTY_SECONDS)
    end
  end
end
