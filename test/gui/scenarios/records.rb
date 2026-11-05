# frozen_string_literal: true

module DotPopperGui
  # The Records screen, offered once a round has finished: opened from
  # the title by a click and by a gamepad's X, and left by a click, by
  # Escape, which must not quit the game from there, and by B.
  class RecordsScenario < Scenario
    scenario :records

    def play
      check(!show.records_offered?, "a first-time title offers no records")
      quick_round
      check(show.records_offered?, "the title offers the records once a round has finished")
      open_by_click
      lit = screenshot.lit_in(DotPopper::Presentation::Rect.new(x: layout.center_x - 200, y: layout.top,
                                                                width: 400, height: layout.safe.height * 0.5))
      check(lit > 100, "the Records screen shows its words (#{lit} light pixels)")
      click(layout.center_x, layout.center_y)
      closed("a click")
      open_by_click
      key(:escape)
      closed("Escape")
      pad(:x)
      check(show.records?, "a gamepad's X opens the records")
      pad(:b)
      closed("a gamepad's B")
    end

    private

    def open_by_click
      reach = show.records_reach
      click(reach.center_x, reach.center_y)
      check(show.records?, "a click on Your records opens them")
    end

    def closed(how)
      check(!show.records? && show.title?, "#{how} goes back to the title, and starts no round")
    end
  end
end
