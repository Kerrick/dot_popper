# frozen_string_literal: true

module DotPopper
  # Watches a Cabinet's events (Cabinet#subscribe) for the Achievements a game earns,
  # and decides nothing: it only reads what the rules report. #earned
  # lists, in Achievement::IDS order, every achievement the game in play,
  # or the one just finished, has earned so far.
  #
  # Dots, the clock, and a game's length are read from each event, which
  # carries them as the rules settled them: a popped dot's place in the
  # stack, the clock after its second.
  class AchievementWatch
    def initialize
      @watching = false
      @targets = {}
      reset
    end

    def earned = Achievement::IDS.select { @found.include?(it) }

    def call(event)
      case event
      when Events::GameStarted then begin_game(event)
      when Events::Popped then popped(event) if @watching
      when Events::Penalized then penalized(event) if @watching
      when Events::Missed then @tapped = true
      when Events::GameEnded then ended(event)
      end
    end

    private

    def reset
      @found = []
      @sharp = 0
      @dots_in_a_row = 0
      @mistaken = false
      @low = false
      @early = 0
      @last_pop = nil
      @covered = false
      @tapped = false
    end

    # A game begins with the row it has: none from Play, and from the
    # tutorial, the dots popped there since its last mistake.
    def begin_game(started)
      reset
      @watching = true
      @dots_in_a_row = started.dots_in_a_row
    end

    def popped(event)
      dots = event.dots.to_a
      sharp(event.dot, dots.take_while { it.id != event.dot.id })
      last = @last_pop
      time_to_pop(event.elapsed - last) if last
      dots_in_a_row
      early(event)
      clock(event)
      find(:comeback) if @low && event.countdown.remaining >= Achievement::BACK
      appeared(event.spawned, dots.take_while { it.id != event.spawned.id }, event)
    end

    def penalized(event)
      @dots_in_a_row = 0
      @mistaken = true
      @tapped = true
      clock(event)
    end

    def ended(event)
      find(:big_score) if event.score >= Achievement::BIG_SCORE
      find(:long_haul) if event.elapsed >= Achievement::LONG_HAUL
    end

    def sharp(dot, above)
      share = Visibility.of(dot, above)
      find(:sharpshooter) if share < Achievement::SHARP
      @sharp += 1 if share < Achievement::SHARP_TRIO_BELOW
      find(:sharp_trio) if @sharp >= Achievement::SHARP_TRIO
    end

    # +seconds+ passed between the last pop and this one.
    def time_to_pop(seconds)
      find(:patience) if @covered && !@tapped && seconds >= Achievement::PATIENCE
      find(:blink) if seconds < Achievement::BLINK
    end

    def dots_in_a_row
      @dots_in_a_row += 1
      find(:steady) if @dots_in_a_row >= Achievement::STEADY
      find(:unshaken) if @dots_in_a_row >= Achievement::UNSHAKEN
      find(:shake_off) if @mistaken && @dots_in_a_row >= Achievement::SHAKE_OFF
    end

    def early(popped)
      @early += 1 if popped.elapsed <= Achievement::FAST_START_SECONDS
      find(:fast_start) if @early >= Achievement::FAST_START
    end

    def clock(tapped) = (@low ||= tapped.countdown.remaining <= Achievement::BRINK)

    # A bright dot has slid under the others: whether it spawned with no
    # room for a fingertip yet, so the wait to pop it is waiting for it to
    # slide out, not for the player.
    def appeared(dot, above, popped)
      @covered = !target(dot.radius).clear_on?(dot.x, dot.y, above.select { it.overlaps?(dot) })
      @tapped = false
      @last_pop = popped.elapsed
    end

    def target(radius) = @targets[radius] ||= TouchTarget.on(radius)

    def find(id) = (@found << id unless @found.include?(id))
  end
end
