# frozen_string_literal: true

module DotPopper
  # Watches a Cabinet's events (Cabinet#subscribe) for the Achievements a game earns,
  # and decides nothing: it only reads what the rules report and the
  # game they happened in. #earned lists, in Achievement::IDS order, every achievement
  # the game in play, or the one just finished, has earned so far.
  #
  # Dots, the clock, and a game's length are read from the game itself
  # when an event arrives, which is when the rules have already settled
  # them: a popped dot's place in the stack, the clock after its second.
  class AchievementWatch
    def initialize
      @game = nil
      @targets = {}
      reset
    end

    def earned = Achievement::IDS.select { @found.include?(it) }

    def call(event)
      game = @game
      case event
      when Events::GameStarted then begin_game(event.game)
      when Events::Popped then popped(event, game) if game
      when Events::Penalized then penalized(game) if game
      when Events::Missed then @tapped = true
      when Events::GameEnded then ended(event)
      end
    end

    private

    def reset
      @found = []
      @sharp = 0
      @run = 0
      @slipped = false
      @low = false
      @early = 0
      @last_pop = nil
      @covered = false
      @tapped = false
    end

    def begin_game(game)
      reset
      @game = game
    end

    def popped(event, game)
      dots = game.dots.to_a
      sharp(event.dot, dots.take_while { it.id != event.dot.id })
      last = @last_pop
      waited(game.elapsed - last) if last
      streak
      early(game)
      clock(game)
      find(:comeback) if @low && game.countdown.remaining >= Achievement::BACK
      appeared(event.spawned, dots.take_while { it.id != event.spawned.id }, game)
    end

    def penalized(game)
      @run = 0
      @slipped = true
      @tapped = true
      clock(game)
    end

    def ended(event)
      find(:big_score) if event.score >= Achievement::BIG_SCORE
      find(:long_haul) if event.game.elapsed >= Achievement::LONG_HAUL
    end

    def sharp(dot, above)
      share = Visibility.of(dot, above)
      find(:sharpshooter) if share < Achievement::SHARP
      @sharp += 1 if share < Achievement::SHARP_TRIO_BELOW
      find(:sharp_trio) if @sharp >= Achievement::SHARP_TRIO
    end

    # +seconds+ passed between the last pop and this one.
    def waited(seconds)
      find(:patience) if @covered && !@tapped && seconds >= Achievement::PATIENCE
      find(:blink) if seconds < Achievement::BLINK
    end

    def streak
      @run += 1
      find(:steady) if @run >= Achievement::STEADY
      find(:unshaken) if @run >= Achievement::UNSHAKEN
      find(:shake_off) if @slipped && @run >= Achievement::SHAKE_OFF
    end

    def early(game)
      @early += 1 if game.elapsed <= Achievement::FAST_START_SECONDS
      find(:fast_start) if @early >= Achievement::FAST_START
    end

    def clock(game) = (@low ||= game.countdown.remaining <= Achievement::BRINK)

    # A fresh dot has slid under the others: whether it spawned with no
    # room for a fingertip yet, so the wait to pop it is waiting for it to
    # slide out, not for the player.
    def appeared(dot, above, game)
      @covered = !target(dot.radius).clear_on?(dot.x, dot.y, above.select { it.overlaps?(dot) })
      @tapped = false
      @last_pop = game.elapsed
    end

    def target(radius) = @targets[radius] ||= TouchTarget.on(radius)

    def find(id) = (@found << id unless @found.include?(id))
  end
end
