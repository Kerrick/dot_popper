# frozen_string_literal: true

module DotPopperGui
  # Each theme's screens kept as screenshots to look at: Home, a
  # crowded round, Game Over, the notice of a new theme, and the Themes
  # screen. DOT_POPPER_THEME names the theme; DOT_POPPER_THEME_UNLOCKS
  # unlocks them; DOT_POPPER_GALLERY names the shots. Not part of rake
  # test:gui: it is for reviewing the themes.
  class ThemesGalleryScenario < Scenario
    scenario :themes_gallery

    def play
      tag = ENV.fetch("DOT_POPPER_GALLERY", "themes")
      theme = ENV.fetch("DOT_POPPER_THEME", "classic")
      theme_keeper = show.instance_variable_get(:@theme_keeper)
      theme_keeper.told(theme_keeper.arrival) until theme_keeper.arrival.nil?
      wait(1.0)
      keep_screenshot("#{tag}-#{theme}-home")
      start_game
      14.times { pop_bright }
      wait(0.5)
      keep_screenshot("#{tag}-#{theme}-round")
      run_out_the_clock
      wait(2.5)
      keep_screenshot("#{tag}-#{theme}-over")
      continue_to_home
      theme_keeper.instance_variable_set(:@told, [])
      frames(4)
      keep_screenshot("#{tag}-#{theme}-arrival")
      show.back
      show.open_stats
      show.open_themes
      frames(4)
      keep_screenshot("#{tag}-#{theme}-themes")
    end
  end
end
