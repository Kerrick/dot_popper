# frozen_string_literal: true

module DotPopperGui
  # The tutorial skipped: by Escape, which goes on to the game and never
  # quits the game, and by a tap on its skip button, drawn in its corner.
  # Each skip takes the tutorial away, and the game it played over plays
  # on at once from the state it is in: the second, after the player's
  # first pop. DOT_POPPER_TUTORIAL=1 opens the tutorial on every Play, so
  # one session tries both.
  class TutorialSkipScenario < Scenario
    scenario :tutorial_skip

    def play
      open_tutorial
      key(:escape)
      check(show.playing?, "Escape skips it, and its game plays on at once")
      check_equal([0, 1], [game.score, game.dots.size], "from its first dot")
      run_out_the_clock
      continue_to_home
      open_tutorial
      wait_for("the first bright dot", within: 900) { show.tutorial&.beat == :aim }
      bright = show.tutorial.dots.first
      click(bright.x, bright.y)
      paused = game
      button = show.skip_reach
      lit = screenshot.lit_in(button)
      check(lit >= 10, "the skip button is drawn (#{lit} light pixels)")
      click(button.center_x, button.center_y)
      check(show.playing?, "a tap on the skip button skips it, and its game plays on at once")
      check(game.equal?(paused), "the same game")
      check_equal([1, [true, false]], [game.score, game.dots.map(&:popped?)], "with the pop the player made")
      frames(1)
      check_equal([game.score, game.countdown.whole_seconds], [show.hud.score, show.hud.seconds], "which the HUD shows")
      check_equal(2, story.count(:GameStarted), "each tutorial's game begins play once")
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
