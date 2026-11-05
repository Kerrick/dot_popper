# frozen_string_literal: true

module DotPopperGui
  # The words follow the hand: Click with the mouse, Tap with a finger,
  # Press A with a gamepad, on the title and on Game Over, as the
  # Show's words say them.
  class WordsScenario < Scenario
    scenario :words

    def play
      check_equal("Click anywhere to play", words.play, "a computer starts out saying Click")
      title_drawn
      touch_move(layout.center_x, layout.center_y)
      check_equal("Tap anywhere to play", words.play, "a finger on the screen makes it Tap")
      check_equal("Tap a bright dot", words.legend.first, "the legend says Tap too")
      move(layout.center_x, layout.center_y)
      check_equal("Click anywhere to play", words.play, "the mouse makes it Click again")
      pad(:dpup)
      check_equal("Press A to play", words.play, "a gamepad's button makes it Press A")
      title_drawn
      start_round(method(:touch))
      pop_fresh(method(:touch))
      run_out_the_clock
      check_equal("Tap to continue", words.continue, "Game Over says Tap after a round played by touch")
      move(layout.center_x, layout.center_y)
      check_equal("Click to continue", words.continue, "the mouse makes it Click")
      pad(:dpdown)
      check_equal("Press A to continue", words.continue, "a gamepad makes it Press A")
      continue_to_title(->(*) { pad(:start) })
    end

    private

    def title_drawn
      wait(0.5)
      lit = screenshot.lit_in(DotPopper::Presentation::Rect.new(x: layout.center_x - 200, y: layout.center_y - 150,
                                                                width: 400, height: 300))
      check(lit > 100, "the title's words are drawn (#{lit} light pixels)")
    end
  end
end
