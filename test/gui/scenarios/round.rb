# frozen_string_literal: true

module DotPopperGui
  # A whole round, as a first-time player has it: the title, a round
  # with a few pops and one tap too soon on a popped dot over the fresh
  # one, its reveal and Game Over's lesson, the clock running out, and
  # back to the title. The score and the clock are worked out alongside,
  # from the rules' numbers, and the save files checked once it is over.
  # With DOT_POPPER_NO_SHADERS=1, the same round draws without shaders.
  class RoundScenario < Scenario
    scenario :round

    R = DotPopper::Rules
    POPS = 4

    def play
      check(show.title?, "the game opens on the title")
      start_round
      wait(0.5)
      shot = screenshot
      check_fresh_pixel(fresh_dot, shot)
      check_hud_drawn(shot)
      POPS.times { pop_fresh }
      expect(pops: POPS, slips: 0)
      tap_too_soon
      expect(pops: POPS, slips: 1)
      run_out_the_clock
      game_over
      continue_to_title
      check_equal(%i[RoundStarted RoundEnded TitleShown], story & %i[RoundStarted RoundEnded TitleShown],
                  "the screens come in order: title, round, Game Over, title")
    end

    private

    # Checks the score and the clock are what the rules make of +pops+
    # and +slips+: a point and a second for each pop, two of each lost to
    # each slip, the score never below zero, and the clock down by the
    # game time that has passed.
    def expect(pops:, slips:)
      check_equal(expected_score(pops, slips), round.score, "the score after #{pops} pops and #{slips} slips")
      granted = R::STARTING_SECONDS + (pops * R::POP_SECONDS) - (slips * R::PENALTY_SECONDS)
      check_close(granted, round.countdown.remaining + round.elapsed, "the clock's time left and time played add up")
    end

    def expected_score(pops, slips)
      [(pops * R::POP_POINTS) - (slips * R::PENALTY_POINTS), R::LOWEST_SCORE].max
    end

    # Waits for a popped dot to lie over the fresh one, and taps between
    # their middles, where the popped dot is on top and the fresh one is
    # under it.
    def tap_too_soon
      x, y = wait_for("a popped dot over the fresh one", within: 1200) { covering_point }
      before = events.size
      click(x, y)
      penalty = events.drop(before).grep(DotPopper::Events::Penalized).first
      check(penalty, "a click on a popped dot over the fresh one is a slip")
      check(!show.effects.reveals.empty?, "the fresh dot hidden under it is outlined")
    end

    def covering_point
      fresh = fresh_dot
      return unless inside_window?(fresh)

      round.dots.each do |dot|
        next unless dot.popped? && dot.overlaps?(fresh)

        x = (dot.x + fresh.x) / 2.0
        y = (dot.y + fresh.y) / 2.0
        top = round.dots.top_at(x, y)
        return [x, y] if top&.popped? && round.dots.fresh_beneath(top, x, y)
      end
      nil
    end

    def game_over
      ended = events.grep(DotPopper::Events::RoundEnded).last
      score = expected_score(POPS, 1)
      check_equal(score, ended.score, "Game Over's score")
      check_close(R::STARTING_SECONDS + POPS - (R::PENALTY_SECONDS * 1), ended.round.elapsed,
                  "the round lasted the time it was given")
      check_equal(words.covered, show.finale.lesson, "Game Over teaches the stacking rule")
      wait(1.5)
      lit = screenshot.lit_in(DotPopper::Presentation::Rect.new(x: layout.center_x - 120, y: layout.center_y - 160,
                                                                width: 240, height: 200))
      check(lit > 100, "Game Over shows its heading and score (#{lit} light pixels)")
      check_saves(score)
    end

    def check_saves(score)
      log = File.readlines(saved("rounds.csv"), chomp: true)
      check_equal(2, log.size, "rounds.csv has its header and the round")
      check_equal(score.to_s, log.last.split(",")[2], "rounds.csv logs the score")
      check(File.read(saved("best_score.txt")).include?("=#{score}"), "best_score.txt keeps the best")
      check(File.file?(saved("lifetime.txt")), "lifetime.txt is saved")
      check(File.file?(saved("taught.txt")), "taught.txt counts the lesson")
    end
  end
end
