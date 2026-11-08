# frozen_string_literal: true

module DotPopperGui
  # The tutorial skipped: by Escape, which goes on to the round and never
  # quits the game, and by a tap on its skip button, drawn in its corner.
  # Each skip starts the round at once, as a Play would. DOT_POPPER_TUTORIAL=1
  # opens the tutorial on every Play, so one session tries both.
  class TutorialSkipScenario < Scenario
    scenario :tutorial_skip

    def play
      open_tutorial
      key(:escape)
      check(show.playing?, "Escape skips it, and the round starts at once")
      run_out_the_clock
      continue_to_title
      open_tutorial
      wait(0.5)
      button = show.skip_reach
      lit = screenshot.lit_in(button)
      check(lit >= 10, "the skip button is drawn (#{lit} light pixels)")
      click(button.center_x, button.center_y)
      check(show.playing?, "a tap on the skip button skips it, and the round starts at once")
      check_equal(0, round.score, "the round starts at 0")
      check_equal(2, story.count(:RoundStarted), "each skip starts one round")
    end

    private

    def open_tutorial
      wait(0.5)
      play = show.play_reach
      click(play.center_x, play.center_y)
      check(show.tutorial?, "Play opens the tutorial")
    end
  end
end
