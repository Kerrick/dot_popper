# frozen_string_literal: true

module DotPopperGui
  # The Licences screen, opened from the Records screen by a click on
  # Licences, by the gamepad's X, and by L; scrolled by the mouse wheel,
  # the keys, and a finger's drag; and left by Back, Escape, and B, each
  # time to the Records screen, never past it.
  class LicencesScenario < Scenario
    scenario :licences

    def play
      quick_round
      open_records
      click_licences
      check(show.licences?, "a click on Licences opens them")
      check(show.records?, "over the Records screen")
      page = show.licences_layout.window
      check(show.licences.farthest.positive?, "the page is longer than the window")
      lit = screenshot.lit_in(page)
      check(lit > 100, "the Licences screen shows its text (#{lit} light pixels)")

      wheel(-3)
      check(show.licences.offset.positive?, "the wheel scrolls down")
      before = show.licences.offset
      wheel(1)
      check(show.licences.offset < before, "and back up")
      key(:pagedown)
      check(show.licences.offset > before, "Page Down scrolls a page")
      key(:end)
      check_close(show.licences.farthest, show.licences.offset, "End goes to the end", within: 1e-6)
      key(:home)
      check_equal(0.0, show.licences.offset, "Home goes to the top")
      key(:down)
      check(show.licences.offset.positive?, "an arrow scrolls a line")
      drag_up(page)
      lit = screenshot.lit_in(page)
      check(lit > 100, "the scrolled page still shows text")
      keep_screenshot("licences")

      key(:escape)
      check(show.records? && !show.licences?, "Escape goes back to the Records screen")
      click_licences
      back = show.back_reach
      click(back.center_x, back.center_y)
      check(show.records? && !show.licences?, "a click on Back goes back to the Records screen")
      pad(:x)
      check(show.licences?, "a gamepad's X opens the licences")
      pad(:b)
      check(show.records? && !show.licences?, "a gamepad's B goes back to the Records screen")
      key(:l)
      check(show.licences?, "L opens the licences")
      key(:escape)
      key(:escape)
      check(show.title? && !show.records?, "Escape again goes back to the title, and starts no round")
    end

    private

    def open_records
      reach = show.records_reach
      click(reach.center_x, reach.center_y)
      check(show.records?, "a click on Your records opens them")
    end

    def click_licences
      reach = show.reach_of(:licences)
      click(reach.center_x, reach.center_y)
    end

    # A finger drags the page up by a few lines, along the window's middle.
    def drag_up(window)
      x = window.center_x
      y = window.center_y
      before = show.licences.offset
      touch_down(x, y)
      touch_move(x, y - 60)
      touch_up(x, y - 60)
      check_close(before + 60, show.licences.offset, "a finger's drag moves the page along", within: 1e-6)
    end
  end
end
