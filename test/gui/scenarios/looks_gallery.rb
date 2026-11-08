# frozen_string_literal: true

module DotPopperGui
  # Every look, in the screens it dresses, at the sizes that matter, kept
  # as screenshots to look at side by side: the title, the Records screen,
  # the Looks screen, a round under way and Game Over, on a desktop's
  # windows and on phone-shaped ones. It checks nothing but that each look
  # can be worn; DOT_POPPER_GALLERY names the shots. Needs
  # DOT_POPPER_PAID=1. Not part of rake test:gui: it is for reviewing the
  # looks' design.
  class LooksGalleryScenario < Scenario
    scenario :looks_gallery

    SIZES = [[1200, 800, false], [800, 500, false], [400, 320, false], [400, 850, true], [850, 400, true]].freeze
    ROUNDS = [[1200, 800, false], [400, 850, true]].freeze

    def play
      wardrobe = show.instance_variable_get(:@wardrobe)
      wardrobe.instance_variable_set(:@earned, DotPopper::Presentation::Look::THEMES.map(&:key))
      quick_round
      DotPopper::Presentation::Look::THEMES.each { gallery(wardrobe, it) }
    end

    private

    def tag = ENV.fetch("DOT_POPPER_GALLERY", "looks")

    def gallery(wardrobe, theme)
      wardrobe.wear(theme)
      check(show.worn == theme, "#{theme.key} is worn")
      SIZES.each do |width, height, phone|
        at(width, height, phone) do
          show.close_records if show.records?
          shoot(theme, "title")
          show.open_records
          shoot(theme, "records")
          show.open_looks
          shoot(theme, "looks")
          show.close_looks
          show.close_records
        end
      end
      ROUNDS.each { |width, height, phone| at(width, height, phone) { round_shots(theme) } }
    end

    def round_shots(theme)
      start_round
      4.times { pop_fresh }
      wait(1.2)
      shoot(theme, "round", settle: 0)
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
