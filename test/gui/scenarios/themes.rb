# frozen_string_literal: true

module DotPopperGui
  # A holiday look, from Pro: a game played in its season
  # earns it and wears it; the Stats screen then offers Themes, whose
  # cards choose a theme at once, drawn in its colors, and Back and Escape
  # leave one step at a time. Needs DOT_POPPER_PRO=1 and a date in
  # Halloween's season (DOT_POPPER_TODAY=2026-10-31).
  class ThemesScenario < Scenario
    scenario :themes

    def play
      check(show.worn.key == :halloween, "a pro player wears the theme in season")
      check(!show.themes_offered?, "no records yet, so no Themes")
      quick_game
      open_stats
      check(show.themes_offered?, "the Stats screen offers Themes once a theme is earned")
      reach = show.reach_of(:themes)
      click(reach.center_x, reach.center_y)
      check(show.themes?, "a click on Themes opens it")
      cards = show.themes_layout.cards
      classic = cards.find { it.theme.ordinary? }.rect
      click(classic.center_x, classic.center_y)
      check(show.worn.ordinary?, "a click on the ordinary theme's card wears it at once")
      frames(3)
      night = screenshot.color(layout.safe.x + 2, layout.safe.y + 2)
      check(night[2] > night[0], "the ordinary night is blue over red")
      halloween = cards.find { it.theme.key == :halloween }.rect
      click(halloween.center_x, halloween.center_y)
      check(show.worn.key == :halloween, "a click on Halloween's card wears it")
      key(:escape)
      check(show.stats? && !show.themes?, "Escape leaves Themes for the Stats screen")
      key(:escape)
      check(show.title?, "and then the Stats screen for the title")
      start_game
      check(show.palette.equal?(show.worn.palette), "the game is dressed in the theme worn")
    end

    private

    def open_stats
      reach = show.stats_reach
      click(reach.center_x, reach.center_y)
      check(show.stats?, "a click on Your stats opens them")
    end
  end
end
