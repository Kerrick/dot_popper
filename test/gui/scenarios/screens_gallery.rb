# frozen_string_literal: true

module DotPopperGui
  # The screens a free or a paid player meets, kept as screenshots to look
  # at: the Friend group door and screen (against a server named by
  # DOT_POPPER_SERVER, with DOT_POPPER_GROUP_CODE the seven digits of a
  # group on it), Records, Looks, and Game Over. DOT_POPPER_GALLERY names
  # the shots. Run it once with DOT_POPPER_PAID=1 and once with 0. Not part
  # of rake test:gui: it is for reviewing the screens.
  class ScreensGalleryScenario < Scenario
    scenario :screens_gallery

    SIZES = [[1200, 800, false], [400, 850, true], [850, 400, true], [400, 320, true]].freeze
    P = DotPopper::Presentation

    def play
      show.input = P::InputKind::TOUCH
      start_round
      8.times { pop_fresh }
      run_out_the_clock
      @size = "first"
      shoot("over", settle: 2.5)
      continue_to_title
      wardrobe = show.instance_variable_get(:@wardrobe)
      wardrobe.instance_variable_set(:@earned, P::Look::THEMES.map(&:key).first(2)) if ENV["DOT_POPPER_PAID"] == "1"
      SIZES.each { |width, height, phone| screens(width, height, phone) }
      join
      SIZES.each { |width, height, phone| member(width, height, phone) }
    end

    private

    def tag = ENV.fetch("DOT_POPPER_GALLERY", "screens")
    def panel = show.group_panel
    def code = ENV.fetch("DOT_POPPER_GROUP_CODE", "1234567")

    def fit(width, height, phone)
      show.instance_variable_set(:@window, P::NoWindowControl.new) if phone
      show.input = phone ? P::InputKind::TOUCH : P::InputKind::MOUSE
      resize(width, height) unless L::Graphics.dimensions == [width, height]
      @size = "#{width}x#{height}"
    end

    def screens(width, height, phone)
      fit(width, height, phone)
      shoot("title")
      group_door
      show.open_records
      shoot("records")
      show.open_looks
      shoot("looks")
      show.close_looks
      show.close_records
      game_over
    end

    def group_door
      return unless panel.available?

      panel.open
      shoot("group-door")
      code.each_char { panel.press([:group_digit, it], :touch, 0.0) }
      shoot("group-code")
      code.size.times { panel.press(:group_erase, :touch, 0.0) }
      show.back
    end

    def join
      panel.open
      code.each_char { panel.press([:group_digit, it], :touch, 0.0) }
      panel.press(:group_join, :touch, 0.0)
      wait_for("the group", within: 900) { panel.member? }
      show.back
    end

    def member(width, height, phone)
      fit(width, height, phone)
      panel.open
      shoot("group-member", settle: 1.5)
      show.back
    end

    def game_over
      start_round
      6.times { pop_fresh }
      run_out_the_clock
      shoot("over", settle: 2.5)
      continue_to_title
    end

    def shoot(state, settle: 1.0)
      wait(settle)
      keep_screenshot("#{tag}-#{state}-#{@size}")
    end
  end
end
