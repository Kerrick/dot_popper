# frozen_string_literal: true

module DotPopperGui
  # The website copy's screens, kept as screenshots to look at: the offer
  # with Buy and Paste license key, a pasted key that isn't one, and, run
  # with DOT_POPPER_FAKE_SETDEF=gone, the offer once Pro is no longer sold,
  # Settings with Change Server, and Change Server before and after an
  # address is pasted. Not part of rake test:gui: it is for reviewing them.
  class WebsiteGalleryScenario < Scenario
    scenario :website_gallery

    SIZES = [[1200, 800], [400, 850], [850, 400], [400, 320]].freeze

    def play
      check(show.home?, "the game opens on Home")
      gone = ENV["DOT_POPPER_FAKE_SETDEF"] == "gone"
      wait_for("setdef's answer") { !gone || show.server_offered? }
      quick_game
      SIZES.each { |width, height| shots(width, height, gone) }
    end

    private

    def shots(width, height, gone)
      resize(width, height)
      name = "#{gone ? "gone-" : ""}#{width}x#{height}"
      show.open_stats
      show.open_offer
      wait(0.5)
      keep_screenshot("website-offer-#{name}")
      ::Lota::System.clipboard_text = "not a key"
      show.paste_key
      wait(0.3)
      keep_screenshot("website-offer-invalid-#{name}")
      show.back
      show.back
      settings(name) if gone
    end

    def settings(name)
      show.open_settings
      wait(0.3)
      keep_screenshot("website-settings-#{name}")
      show.open_server
      check(show.server?, "Change Server opens while setdef is gone")
      wait(0.3)
      keep_screenshot("website-server-#{name}")
      ::Lota::System.clipboard_text = "https://groups.example.org"
      show.paste_server
      wait(0.3)
      keep_screenshot("website-server-chosen-#{name}")
      reach = show.reach_of(:server_reset)
      click(reach.center_x, reach.center_y)
      show.back
      show.back
    end
  end
end
