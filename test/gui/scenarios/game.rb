# frozen_string_literal: true

module DotPopperGui
  # A whole game, as a first-time player has it: the title, a game
  # with a few pops and one tap too soon on a popped dot over the fresh
  # one, its reveal and Game Over's lesson, replayed on the pile with no
  # word, the clock running out, and
  # back to the title. The score and the clock are worked out alongside,
  # from the rules' numbers, and the save files checked once it is over.
  # With DOT_POPPER_NO_SHADERS=1, the same game draws without shaders.
  class GameScenario < Scenario
    scenario :game

    R = DotPopper::Rules
    POPS = 4

    def play
      check(show.title?, "the game opens on the title")
      start_game
      wait(0.5)
      shot = screenshot
      check_fresh_pixel(fresh_dot, shot)
      check_hud_drawn(shot)
      POPS.times { pop_fresh }
      expect(pops: POPS, mistakes: 0)
      tap_too_soon
      expect(pops: POPS, mistakes: 1)
      run_out_the_clock
      game_over
      click_empty_space
      continue_to_title
      check_equal(%i[RoundStarted RoundEnded TitleShown], story & %i[RoundStarted RoundEnded TitleShown],
                  "the screens come in order: title, game, Game Over, title")
    end

    private

    # Checks the score and the clock are what the rules make of +pops+
    # and +mistakes+: a point and a second for each pop, two of each lost to
    # each mistake, the score never below zero, and the clock down by the
    # game time that has passed.
    def expect(pops:, mistakes:)
      check_equal(expected_score(pops, mistakes), game.score, "the score after #{pops} pops and #{mistakes} mistakes")
      granted = R::STARTING_SECONDS + (pops * R::POP_SECONDS) - (mistakes * R::PENALTY_SECONDS)
      check_close(granted, game.countdown.remaining + game.elapsed, "the clock's time left and time played add up")
    end

    def expected_score(pops, mistakes)
      [(pops * R::POP_POINTS) - (mistakes * R::PENALTY_POINTS), R::LOWEST_SCORE].max
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

      game.dots.each do |dot|
        next unless dot.popped? && dot.overlaps?(fresh)

        x = (dot.x + fresh.x) / 2.0
        y = (dot.y + fresh.y) / 2.0
        top = game.dots.top_at(x, y)
        return [x, y] if top&.popped? && game.dots.fresh_beneath(top, x, y)
      end
      nil
    end

    def game_over
      ended = events.grep(DotPopper::Events::GameEnded).last
      score = expected_score(POPS, 1)
      check_equal(score, ended.score, "Game Over's score")
      check_close(R::STARTING_SECONDS + POPS - (R::PENALTY_SECONDS * 1), ended.game.elapsed,
                  "the game lasted the time it was given")
      lesson = show.game_over.lesson
      fresh = ended.game.dots.find(&:fresh?)
      check(lesson && lesson.bright == fresh.id, "Game Over teaches the stacking rule from the wrong tap")
      wait_for("the wrong tap replayed on the pile", within: 300) { show.game_over.replayed.positive? }
      check_equal([fresh.id], show.effects.reveals.map(&:follow), "the bright dot it hid is outlined on the pile")
      wait(0.15)
      keep_screenshot("game-over-lesson")
      wait(1.2)
      lit = screenshot.lit_in(DotPopper::Presentation::Rect.new(x: layout.center_x - 120, y: layout.center_y - 160,
                                                                width: 240, height: 200))
      check(lit > 100, "Game Over shows its heading and score (#{lit} light pixels)")
      check_saves(score)
    end

    # A click on Game Over away from its buttons is the pile's alone: it
    # never goes on to the title.
    def click_empty_space
      x = layout.safe.x + (layout.safe.width * 0.06)
      y = layout.safe.y + (layout.safe.height * 0.3)
      check(show.control_at(x, y).nil?, "the place clicked is empty space")
      click(x, y)
      wait(0.3)
      check(show.game_over?, "a click on empty space at Game Over does nothing")
    end

    def check_saves(score)
      log = File.readlines(saved("games.csv"), chomp: true)
      check_equal(2, log.size, "games.csv has its header and the game")
      check_equal(score.to_s, log.last.split(",")[2], "games.csv logs the score")
      check(File.read(saved("score_record.txt")).include?("=#{score}"), "score_record.txt keeps the best")
      check(File.file?(saved("stats.txt")), "stats.txt is saved")
      check(File.file?(saved("taught.txt")), "taught.txt counts the lesson")
    end
  end
end
