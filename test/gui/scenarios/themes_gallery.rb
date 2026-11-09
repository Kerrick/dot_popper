# frozen_string_literal: true

module DotPopperGui
  # Every look, in the screens it dresses, at the sizes that matter, kept
  # as screenshots to look at side by side: the title, the Stats screen,
  # the Looks screen, a game under way and Game Over, on a desktop's
  # windows and on phone-shaped ones. It checks nothing but that each look
  # can be worn; DOT_POPPER_GALLERY names the shots. Needs
  # DOT_POPPER_PAID=1. Not part of rake test:gui: it is for reviewing the
  # looks' design.
  class ThemesGalleryScenario < Scenario
    scenario :themes_gallery

    SIZES = [[1200, 800, false], [800, 500, false], [400, 320, false], [400, 850, true], [850, 400, true]].freeze
    ROUNDS = [[1200, 800, false], [400, 850, true]].freeze

    def play
      theme_keeper = show.instance_variable_get(:@theme_keeper)
      theme_keeper.instance_variable_set(:@earned, DotPopper::Presentation::Style::THEMES.map(&:key))
      quick_game
      DotPopper::Presentation::Style::THEMES.each { gallery(theme_keeper, it) }
    end

    private

    def tag = ENV.fetch("DOT_POPPER_GALLERY", "themes")

    def gallery(theme_keeper, theme)
      theme_keeper.wear(theme)
      check(show.worn == theme, "#{theme.key} is worn")
      SIZES.each do |width, height, phone|
        at(width, height, phone) do
          show.close_stats if show.stats?
          shoot(theme, "title")
          show.open_stats
          shoot(theme, "records")
          show.open_themes
          shoot(theme, "themes")
          show.close_themes
          show.close_stats
        end
      end
      ROUNDS.each { |width, height, phone| at(width, height, phone) { game_shots(theme) } }
    end

    def game_shots(theme)
      start_game
      4.times { pop_fresh }
      wait(1.2)
      shoot(theme, "game", settle: 0)
      run_out_the_clock
      wait(2.5)
      shoot(theme, "over", settle: 0)
      continue_to_title
    end

    def at(width, height, phone)
      show.instance_variable_set(:@window, DotPopper::Presentation::NoWindowControl.new) if phone
      show.input = phone ? DotPopper::Presentation::InputKind::TOUCH : DotPopper::Presentation::InputKind::MOUSE
      resize(width, height) unless L::Graphics.dimensions == [width, height]
      @phone = phone
      yield
    end

    def shoot(theme, state, settle: 1.0)
      wait(settle)
      kind = @phone ? "phone" : "desktop"
      keep_screenshot("#{tag}-#{theme.key}-#{state}-#{kind}-#{layout.width.round}x#{layout.height.round}")
    end
  end
end
