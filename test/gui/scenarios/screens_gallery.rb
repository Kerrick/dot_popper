# frozen_string_literal: true

module DotPopperGui
  # The screens a free or a pro player meets, kept as screenshots to look
  # at: the friend groups' screens (against a server named by
  # DOT_POPPER_SERVER, such as script/group_stub.rb, with
  # DOT_POPPER_GROUP_CODE the seven digits of a group on it), Stats,
  # Themes, and Game Over. DOT_POPPER_GALLERY names the shots. Run it once
  # with DOT_POPPER_PRO=1 and once with 0. Not part of rake test:gui: it
  # is for reviewing the screens.
  class ScreensGalleryScenario < Scenario
    scenario :screens_gallery

    SIZES = [[1200, 800, false], [400, 850, true], [850, 400, true]].freeze
    P = DotPopper::Presentation

    def play
      show.input = P::InputKind::TOUCH
      start_game
      8.times { pop_bright }
      run_out_the_clock
      @size = "first"
      shoot("over", settle: 2.5)
      continue_to_home
      keeper = show.instance_variable_get(:@theme_keeper)
      keeper.receive(%w[ghost]) if ENV["DOT_POPPER_PRO"] == "1"
      keeper.told(keeper.arrival) until keeper.arrival.nil?
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
      shoot("home")
      group_door
      show.open_stats
      shoot("records")
      show.open_themes
      shoot("themes")
      show.close_themes
      show.close_stats
      game_over
    end

    def group_door
      return unless panel.available?

      panel.open
      shoot("group-list")
      return show.back if panel.locked?

      panel.press(:group_join_open, :touch, 0.0)
      panel.press(:notice_go, :touch, 0.0) if panel.asking
      code.each_char { panel.press([:code_digit, it], :touch, 0.0) }
      shoot("group-code")
      show.back
      show.back
    end

    def join
      panel.open
      panel.press(:group_join_open, :touch, 0.0)
      panel.press(:notice_go, :touch, 0.0) if panel.asking
      code.each_char { panel.press([:code_digit, it], :touch, 0.0) }
      panel.press(:code_submit, :touch, 0.0)
      wait_for("the group", within: 900) { panel.page == :group }
      show.back
      show.back
    end

    def member(width, height, phone)
      fit(width, height, phone)
      panel.open
      wait_for("the groups", within: 900) { panel.groups.groups.size >= 3 }
      shoot("group-list", settle: 1.5)
      panel.press([:group_show, panel.groups.groups.find { it.join_code == code }.id], :touch, 0.0)
      wait_for("the standings", within: 900) { panel.group }
      shoot("group-standings", settle: 1.5)
      panel.press(:group_history, :touch, 0.0)
      wait_for("the history", within: 900) { panel.groups.title_changes(panel.group_id) }
      shoot("group-history", settle: 1.5)
      show.back
      show.back
      show.back
      game_over("over-member")
    end

    def game_over(state = "over")
      start_game
      6.times { pop_bright }
      run_out_the_clock
      shoot(state, settle: 2.5)
      continue_to_home
    end

    def shoot(state, settle: 1.0)
      wait(settle)
      keep_screenshot("#{tag}-#{state}-#{@size}")
    end
  end
end
