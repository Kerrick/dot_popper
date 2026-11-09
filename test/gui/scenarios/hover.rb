# frozen_string_literal: true

module DotPopperGui
  # The mouse over the title's "Your records": the button lights up and
  # the pointer becomes the system's pointing hand, and moving away puts
  # both back. A finger never hovers.
  class HoverScenario < Scenario
    scenario :hover

    def play
      quick_game
      reach = show.records_reach
      move(reach.center_x - 20, reach.center_y)
      move(reach.center_x, reach.center_y)
      check_equal :records, show.hovered, "the mouse over Your records hovers it"
      check(app.pointing_hand?, "the pointer is the pointing hand over Your records")
      wait(DotPopper::Presentation::Look::HOVER.seconds * 2)
      check_close 1.0, show.hover.level(:records), "Your records is lit"
      keep_screenshot("hover-records")
      move(layout.safe.x + 20, layout.top + 20)
      check(show.hovered.nil? && !app.pointing_hand?, "moving away clears the hover and the hand")
      wait(DotPopper::Presentation::Look::HOVER.seconds * 2)
      check_close 0.0, show.hover.level(:records), "Your records dims again"
      move(reach.center_x, reach.center_y)
      check(app.pointing_hand?, "the hand is back over Your records")
      touch_move(reach.center_x, reach.center_y)
      check(show.title? && show.hovered.nil? && !app.pointing_hand?, "a finger over it leaves no hover and no hand")
      play = show.play_reach
      move(play.center_x - 30, play.center_y)
      move(play.center_x, play.center_y)
      check_equal :play, show.hovered, "the mouse over Play hovers it"
      check(app.pointing_hand?, "the pointer is the pointing hand over Play")
    end
  end
end
