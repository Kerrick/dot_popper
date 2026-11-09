# frozen_string_literal: true

module DotPopperGui
  # A theme the server has unlocked: the Stats screen offers Themes, whose
  # cards choose a theme at once. Needs DOT_POPPER_PRO=1 and
  # DOT_POPPER_THEME_UNLOCKS=ghost.
  class ThemesScenario < Scenario
    scenario :themes

    def play
      keeper = show.instance_variable_get(:@theme_keeper)
      keeper.told(keeper.arrival) until keeper.arrival.nil?
      quick_game
      open_stats
      check(show.themes_offered?, "the Stats screen offers Themes once the server has unlocked a theme")
      reach = show.reach_of(:themes)
      click(reach.center_x, reach.center_y)
      check(show.themes?, "a click on Themes opens it")
      cards = show.themes_layout.cards
      classic = cards.find { it.theme.ordinary? }.rect
      click(classic.center_x, classic.center_y)
      check(show.in_use.ordinary?, "a click on the ordinary theme's card uses it at once")
      frames(3)
      night = screenshot.color(layout.safe.x + 2, layout.safe.y + 2)
      check(night[2] > night[0], "the ordinary night is blue over red")
      ghost = cards.find { it.theme.key == :ghost }.rect
      click(ghost.center_x, ghost.center_y)
      check(show.in_use.key == :ghost, "a click on Ghost's card uses it")
      key(:escape)
      check(show.stats? && !show.themes?, "Escape leaves Themes for the Stats screen")
      key(:escape)
      check(show.title?, "and then the Stats screen for the title")
      start_game
      check(show.palette.equal?(show.in_use.palette), "the game takes the colors of the theme in use")
    end

    private

    def open_stats
      reach = show.stats_reach
      click(reach.center_x, reach.center_y)
      check(show.stats?, "a click on Your stats opens them")
    end
  end
end
