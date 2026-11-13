# frozen_string_literal: true

module DotPopperGui
  # The words and the hand drawn follow the hand in use: the mouse, a
  # finger, or a gamepad, whose buttons are named, on Home and on
  # Game Over, as the Show's input and words say them.
  class WordsScenario < Scenario
    scenario :words

    MOUSE = DotPopper::Presentation::InputKind::MOUSE
    TOUCH = DotPopper::Presentation::InputKind::TOUCH

    def play
      check_equal(MOUSE, show.input, "a computer starts out with the mouse")
      home_drawn
      touch_move(layout.center_x, layout.center_y)
      check_equal(TOUCH, show.input, "a finger on the screen makes it touch")
      check_equal("Play", words.play, "Play says Play")
      move(layout.center_x, layout.center_y)
      check_equal(TOUCH, show.input, "a motion that goes nowhere, as a window opening under the pointer sends, changes nothing")
      move(layout.center_x + 30, layout.center_y)
      check_equal(MOUSE, show.input, "a real move of the mouse makes it the mouse again")
      pad(:dpup)
      check_equal("Play (A)", words.play, "a gamepad's button makes it Press A, on Play's button")
      home_drawn
      start_game(method(:touch))
      pop_bright(method(:touch))
      run_out_the_clock
      check_equal(TOUCH, show.input, "Game Over follows a game played by touch")
      check_equal("Play again", words.play_again, "and says Play again")
      move(layout.center_x, layout.center_y)
      move(layout.center_x + 30, layout.center_y)
      check_equal(MOUSE, show.input, "a real move of the mouse makes it the mouse")
      pad(:dpdown)
      check_equal("Play again (A)", words.play_again, "a gamepad makes it Press A, on Play again's button")
      continue_to_home(->(*) { pad(:b) })
      quit_prompt
    end

    private

    # B on Home asks "Press B again to quit", clear of Play: the
    # maintainer saw it drawn behind Play's button.
    def quit_prompt
      wait(0.5)
      pad(:b)
      wait(0.2)
      plan = show.home_plan
      check(show.quit_prompt.positive?, "B on Home asks to quit")
      x, y = plan.quit_line
      line = DotPopper::Presentation::Rect.new(x: x - 150, y: y - 12, width: 300, height: 24)
      check(!line.overlaps?(plan.play_button), "the question is clear of Play")
      keep_screenshot("quit-prompt")
      wait(DotPopper::Presentation::Show::QUIT_ASK + 0.2)
      check(show.home? && show.quit_prompt.zero?, "with no second B, the question goes and the game stays")
      key(:escape)
      wait(0.2)
      check_equal("Press Escape again to quit", show.quit_again, "Escape on Home asks, naming Escape")
      keep_screenshot("quit-prompt-escape")
      wait(DotPopper::Presentation::Show::QUIT_ASK + 0.2)
      check(show.home? && show.quit_prompt.zero?, "with no second Escape, the question goes and the game stays")
    end

    def home_drawn
      wait(0.5)
      lit = screenshot.lit_in(DotPopper::Presentation::Rect.new(x: layout.center_x - 200, y: layout.center_y - 150,
                                                                width: 400, height: 300))
      check(lit > 100, "Home's words are drawn (#{lit} light pixels)")
    end
  end
end
