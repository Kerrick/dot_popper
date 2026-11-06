# frozen_string_literal: true

module DotPopperGui
  # The Credits screen, opened from the Records screen by a click on
  # Credits, by the gamepad's X, and by L; scrolled by the mouse wheel,
  # the keys, and a finger's drag; and left by Back, Escape, and B, each
  # time to the Records screen, never past it.
  class CreditsScenario < Scenario
    scenario :credits

    def play
      quick_round
      open_records
      click_credits
      check(show.credits?, "a click on Credits opens them")
      check(show.records?, "over the Records screen")
      page = show.credits_layout.window
      check(show.credits.farthest.positive?, "the page is longer than the window")
      lit = screenshot.lit_in(page)
      check(lit > 100, "the Credits screen shows its text (#{lit} light pixels)")
      keep_screenshot("credits-top")

      wheel(-3)
      check(show.credits.offset.positive?, "the wheel scrolls down")
      before = show.credits.offset
      wheel(1)
      check(show.credits.offset < before, "and back up")
      key(:pagedown)
      check(show.credits.offset > before, "Page Down scrolls a page")
      keep_screenshot("credits-license")
      key(:end)
      check_close(show.credits.farthest, show.credits.offset, "End goes to the end", within: 1e-6)
      key(:home)
      check_equal(0.0, show.credits.offset, "Home goes to the top")
      key(:down)
      check(show.credits.offset.positive?, "an arrow scrolls a line")
      drag_up(page)
      lit = screenshot.lit_in(page)
      check(lit > 100, "the scrolled page still shows text")
      keep_screenshot("credits")

      key(:escape)
      check(show.records? && !show.credits?, "Escape goes back to the Records screen")
      click_credits
      back = show.back_reach
      click(back.center_x, back.center_y)
      check(show.records? && !show.credits?, "a click on Back goes back to the Records screen")
      pad(:x)
      check(show.credits?, "a gamepad's X opens the credits")
      pad(:b)
      check(show.records? && !show.credits?, "a gamepad's B goes back to the Records screen")
      key(:c)
      check(show.credits?, "C opens the credits")
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

    def click_credits
      reach = show.reach_of(:credits)
      click(reach.center_x, reach.center_y)
    end

    # A finger drags the page up by a few lines, along the window's middle.
    def drag_up(window)
      x = window.center_x
      y = window.center_y
      before = show.credits.offset
      touch_down(x, y)
      touch_move(x, y - 60)
      touch_up(x, y - 60)
      check_close(before + 60, show.credits.offset, "a finger's drag moves the page along", within: 1e-6)
    end
  end
end
