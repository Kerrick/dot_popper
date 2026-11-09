# frozen_string_literal: true

module DotPopperGui
  # The Stats screen, offered once a game has finished: opened from
  # the title by a click and by a gamepad's X, and left by a click on
  # Back, by Escape, which must not quit the game from there, and by B. A
  # click elsewhere on it does nothing.
  class StatsScenario < Scenario
    scenario :stats

    def play
      check(!show.stats_offered?, "a first-time title offers no records")
      quick_game
      check(show.stats_offered?, "the title offers the records once a game has finished")
      open_by_click
      lit = screenshot.lit_in(DotPopper::Presentation::Rect.new(x: layout.center_x - 200, y: layout.top,
                                                                width: 400, height: layout.safe.height * 0.5))
      check(lit > 100, "the Stats screen shows its words (#{lit} light pixels)")
      click(*empty_point)
      check(show.stats?, "a click elsewhere does nothing")
      back = show.back_reach
      click(back.center_x, back.center_y)
      closed("a click on Back")
      open_by_click
      key(:escape)
      closed("Escape")
      pad(:x)
      check(show.stats?, "a gamepad's X opens the records")
      pad(:b)
      closed("a gamepad's B")
    end

    private

    def open_by_click
      reach = show.stats_reach
      click(reach.center_x, reach.center_y)
      check(show.stats?, "a click on Your stats opens them")
    end

    def closed(how)
      check(!show.stats? && show.home?, "#{how} goes back to the title, and starts no game")
    end
  end
end
