# frozen_string_literal: true

module DotPopperGui
  # The limit on free plays, kept as screenshots to look at: the title with
  # none left, and the offer Play leads to then. It needs DOT_POPPER_PAID=0,
  # DOT_POPPER_FAKE_STORE=1 and DOT_POPPER_FREE_PLAYS=0, since a computer
  # has no store and counts nothing. Not part of rake test:gui: it is for
  # reviewing the screens.
  class PlaysGalleryScenario < Scenario
    scenario :plays_gallery

    SIZES = [[1200, 800], [400, 850], [850, 400]].freeze

    def play
      check(show.title?, "the game opens on the title")
      check(show.plays_line == "No plays left today", "the title says no plays are left")
      SIZES.each { |width, height| shots(width, height) }
    end

    private

    def shots(width, height)
      resize(width, height)
      wait(1.0)
      keep_screenshot("plays-title-#{width}x#{height}")
      reach = show.play_reach
      click(reach.center_x, reach.center_y)
      check(show.offer?, "Play leads to the offer with no plays left")
      wait_for("the price", within: 600) { show.offer_price }
      wait(1.0)
      keep_screenshot("plays-offer-#{width}x#{height}")
      show.back
      check(show.title?, "Back returns to the title")
    end
  end
end
