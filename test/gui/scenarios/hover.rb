# frozen_string_literal: true

module DotPopperGui
  # The mouse over the title's "Your stats": the button lights up and
  # the pointer becomes the system's pointing hand, and moving away puts
  # both back. A finger never hovers.
  class HoverScenario < Scenario
    scenario :hover

    def play
      quick_game
      reach = show.stats_reach
      move(reach.center_x - 20, reach.center_y)
      move(reach.center_x, reach.center_y)
      check_equal :stats, show.hovered, "the mouse over Your stats hovers it"
      check(app.pointing_hand?, "the pointer is the pointing hand over Your stats")
      wait(DotPopper::Presentation::Style::HOVER.seconds * 2)
      check_close 1.0, show.hover.level(:stats), "Your stats is lit"
      keep_screenshot("hover-stats")
      move(*empty_point)
      check(show.hovered.nil? && !app.pointing_hand?, "moving away clears the hover and the hand")
      wait(DotPopper::Presentation::Style::HOVER.seconds * 2)
      check_close 0.0, show.hover.level(:stats), "Your stats dims again"
      move(reach.center_x, reach.center_y)
      check(app.pointing_hand?, "the hand is back over Your stats")
      touch_move(reach.center_x, reach.center_y)
      check(show.title? && show.hovered.nil? && !app.pointing_hand?, "a finger over it leaves no hover and no hand")
      play = show.play_reach
      move(play.center_x - 30, play.center_y)
      move(play.center_x, play.center_y)
      check_equal :play, show.hovered, "the mouse over Play hovers it"
      check(app.pointing_hand?, "the pointer is the pointing hand over Play")
    end

    private

    # A point in the safe area that no button reaches, so moving the mouse
    # there is moving away. The top left corner is the Group button's.
    def empty_point
      safe = layout.safe
      points = (1..9).flat_map { |i| (1..9).map { |j| [safe.x + (safe.width * i / 10.0), safe.y + (safe.height * j / 10.0)] } }
      points.find { |x, y| show.control_at(x, y).nil? } or raise "no empty point on the title"
    end
  end
end
