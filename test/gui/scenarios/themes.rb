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
      reach = show.reach_of(:themes)
      check(reach, "Home offers Themes")
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
      check(show.on_home?, "Escape leaves Themes for Home")
      start_game
      check(show.palette.equal?(show.in_use.palette), "the game takes the colors of the theme in use")
    end

    private

  end
end
