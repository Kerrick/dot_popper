# frozen_string_literal: true

module DotPopperGui
  # The words follow the hand: Click with the mouse, Tap with a finger,
  # and a gamepad's buttons by name, on the title and on Game Over, as
  # the Show's words say them.
  class WordsScenario < Scenario
    scenario :words

    def play
      check_equal("Click a bright dot", words.legend.first, "a computer starts out saying Click")
      title_drawn
      touch_move(layout.center_x, layout.center_y)
      check_equal("Tap a bright dot", words.legend.first, "a finger on the screen makes it Tap")
      check_equal("Play", words.play, "Play says Play")
      move(layout.center_x, layout.center_y)
      check_equal("Tap a bright dot", words.legend.first, "a motion that goes nowhere, as a window opening under the pointer sends, changes nothing")
      move(layout.center_x + 30, layout.center_y)
      check_equal("Click a bright dot", words.legend.first, "a real move of the mouse makes it Click again")
      pad(:dpup)
      check_equal("Play (A)", words.play, "a gamepad's button makes it Press A, on Play's button")
      title_drawn
      start_round(method(:touch))
      pop_fresh(method(:touch))
      run_out_the_clock
      check_equal("Wait for the bright dot to slide out, then tap it.", words.covered.last,
                  "Game Over says Tap after a round played by touch")
      move(layout.center_x, layout.center_y)
      move(layout.center_x + 30, layout.center_y)
      check_equal("Wait for the bright dot to slide out, then click it.", words.covered.last,
                  "a real move of the mouse makes it Click")
      pad(:dpdown)
      check_equal("Continue (A)", words.continue, "a gamepad makes it Press A, on Continue's button")
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
