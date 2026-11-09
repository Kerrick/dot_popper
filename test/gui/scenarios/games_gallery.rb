# frozen_string_literal: true

module DotPopperGui
  # The limit on free games, kept as screenshots to look at: the title with
  # none left, and the offer Play leads to then. It needs
  # DOT_POPPER_FREE_GAMES=0, since a scenario counts no games otherwise.
  # Not part of rake test:gui: it is for
  # reviewing the screens.
  class GamesGalleryScenario < Scenario
    scenario :games_gallery

    SIZES = [[1200, 800], [400, 850], [850, 400]].freeze

    def play
      check(show.title?, "the game opens on the title")
      check(show.games_line == "No games left today", "the title says no games are left")
      SIZES.each { |width, height| shots(width, height) }
    end

    private

    def shots(width, height)
      resize(width, height)
      wait(1.0)
      keep_screenshot("games-title-#{width}x#{height}")
      reach = show.play_reach
      click(reach.center_x, reach.center_y)
      check(show.offer?, "Play leads to the offer with no games left")
      wait_for("the price", within: 600) { show.offer_price }
      wait(1.0)
      keep_screenshot("games-offer-#{width}x#{height}")
      show.back
      check(show.title?, "Back returns to the title")
    end
  end
end
