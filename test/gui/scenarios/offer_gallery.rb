# frozen_string_literal: true

module DotPopperGui
  # The offer of Pro, kept as screenshots to look at: the way
  # to it on the Stats screen, the offer as a phone and a desktop window
  # lay it out, and the thanks after the purchase, from a test build's
  # fake store. Not part of rake test:gui: it is for reviewing the screen.
  class OfferGalleryScenario < Scenario
    scenario :offer_gallery

    SIZES = [[1200, 800], [400, 320], [400, 850], [850, 400]].freeze
    P = DotPopper::Presentation

    def play
      check(show.home?, "the game opens on the title")
      quick_game
      show.input = P::InputKind::TOUCH
      SIZES.each { |width, height| shots(width, height) }
      resize(1200, 800)
      show.open_stats
      show.open_offer
      wait_for("the price", within: 600) { show.offer_price }
      buy = show.reach_of(:buy)
      click(buy.center_x, buy.center_y)
      wait_for("the purchase", within: 600) { show.offer_status == show.words.offer[:thanks] }
      keep_screenshot("offer-thanks-1200x800")
    end

    private

    def shots(width, height)
      resize(width, height)
      show.open_stats
      wait(1.0)
      keep_screenshot("offer-records-#{width}x#{height}")
      show.open_offer
      wait_for("the price", within: 600) { show.offer_price }
      wait(1.0)
      keep_screenshot("offer-#{width}x#{height}")
      show.back
      from_a_tap(:themes, width, height)
      from_a_tap(:achievements, width, height)
      show.back
    end

    # A Free player taps what comes with Pro: the offer opens leading with it, and Back returns to where they were.
    def from_a_tap(feature, width, height)
      if feature == :themes
        show.open_themes
        wait(0.5)
        keep_screenshot("themes-#{width}x#{height}")
        card = show.themes_layout.cards.last.rect
        click(card.center_x, card.center_y)
      else
        reach = show.reach_of(:achievements)
        check(!reach.nil?, "the achievements can be tapped on the Stats screen at #{width}x#{height}")
        click(reach.center_x, reach.center_y)
      end
      check(show.offer? && show.offer_focus == feature, "tapping #{feature} opens the offer leading with it")
      wait_for("the price", within: 600) { show.offer_price }
      wait(1.0)
      keep_screenshot("offer-from-#{feature}-#{width}x#{height}")
      show.back
      check(!show.offer? && show.stats?, "Back from the offer returns to the Stats screen") if feature == :achievements
      check(!show.offer? && show.themes?, "Back from the offer returns to the Themes screen") if feature == :themes
      show.back if feature == :themes
    end
  end
end
