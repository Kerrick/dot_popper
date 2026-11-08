# frozen_string_literal: true

module DotPopper
  # Watches a Game's events (Game#subscribe) for the Feats a round earns,
  # and decides nothing: it only reads what the rules report and the
  # round they happened in. #earned lists, in Feat::IDS order, every feat
  # the round in play, or the one just finished, has earned so far.
  #
  # Dots, the clock, and a round's length are read from the round itself
  # when an event arrives, which is when the rules have already settled
  # them: a popped dot's place in the stack, the clock after its second.
  class FeatWatch
    def initialize
      @round = nil
      @targets = {}
      reset
    end

    def earned = Feat::IDS.select { @found.include?(it) }

    def call(event)
      round = @round
      case event
      when Events::RoundStarted then begin_round(event.round)
      when Events::Popped then popped(event, round) if round
      when Events::Penalized then penalized(round) if round
      when Events::Missed then @tapped = true
      when Events::RoundEnded then ended(event)
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

    def begin_round(round)
      reset
      @round = round
    end

    def popped(event, round)
      dots = round.dots.to_a
      sharp(event.dot, dots.take_while { it.id != event.dot.id })
      last = @last_pop
      waited(round.elapsed - last) if last
      streak
      early(round)
      clock(round)
      find(:comeback) if @low && round.countdown.remaining >= Feat::BACK
      appeared(event.spawned, dots.take_while { it.id != event.spawned.id }, round)
    end

    def penalized(round)
      @run = 0
      @slipped = true
      @tapped = true
      clock(round)
    end

    def ended(event)
      find(:big_score) if event.score >= Feat::BIG_SCORE
      find(:long_haul) if event.round.elapsed >= Feat::LONG_HAUL
    end

    def sharp(dot, above)
      share = Visibility.of(dot, above)
      find(:sharpshooter) if share < Feat::SHARP
      @sharp += 1 if share < Feat::SHARP_TRIO_BELOW
      find(:sharp_trio) if @sharp >= Feat::SHARP_TRIO
    end

    # +seconds+ passed between the last pop and this one.
    def waited(seconds)
      find(:patience) if @covered && !@tapped && seconds >= Feat::PATIENCE
      find(:blink) if seconds < Feat::BLINK
    end

    def streak
      @run += 1
      find(:steady) if @run >= Feat::STEADY
      find(:unshaken) if @run >= Feat::UNSHAKEN
      find(:shake_off) if @slipped && @run >= Feat::SHAKE_OFF
    end

    def early(round)
      @early += 1 if round.elapsed <= Feat::FAST_START_SECONDS
      find(:fast_start) if @early >= Feat::FAST_START
    end

    def clock(round) = (@low ||= round.countdown.remaining <= Feat::BRINK)

    # A fresh dot has slid under the others: whether it spawned with no
    # room for a fingertip yet, so the wait to pop it is waiting for it to
    # slide out, not for the player.
    def appeared(dot, above, round)
      @covered = !target(dot.radius).clear_on?(dot.x, dot.y, above.select { it.overlaps?(dot) })
      @tapped = false
      @last_pop = round.elapsed
    end

    def target(radius) = @targets[radius] ||= TouchTarget.on(radius)

    def find(id) = (@found << id unless @found.include?(id))
  end
end
