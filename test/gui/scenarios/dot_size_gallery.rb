# frozen_string_literal: true

module DotPopperGui
  # The dot sizes' names, kept as screenshots to look at: Settings' "Dot
  # size", Stats with games of both sizes, the shared result, and a friend
  # group's page with each size, on the narrowest window, a phone held each
  # way, the desktop window, a tall narrow window where the two sizes look
  # alike, and a big monitor. The groups need Pro (DOT_POPPER_PRO=1) and a
  # server named by DOT_POPPER_SERVER, such as script/group_stub.rb. Not
  # part of rake test:gui: it is for reviewing the screens.
  class DotSizeGalleryScenario < Scenario
    scenario :dot_size_gallery

    SIZES = [[400, 568, true], [400, 850, true], [844, 390, true], [1200, 800, false], [560, 1600, true], [2560, 1440, false]].freeze
    P = DotPopper::Presentation
    DEFAULT = DotPopper::DotSizing::DEFAULT

    def play
      @size = "1200x800"
      one_game
      share
      continue_to_home
      cabinet.sizing = DEFAULT.toggled
      one_game
      continue_to_home
      cabinet.sizing = DEFAULT
      one_game
      continue_to_home
      join
      SIZES.each { |width, height, phone| screens(width, height, phone) }
    end

    private

    def panel = show.group_panel
    def code = ENV.fetch("DOT_POPPER_GROUP_CODE", "1234567")

    def fit(width, height, phone)
      show.instance_variable_set(:@window, P::NoWindowControl.new) if phone
      show.input = phone ? P::InputKind::TOUCH : P::InputKind::MOUSE
      resize(width, height) unless L::Graphics.dimensions == [width, height]
      wait(0.5)
      @size = "#{width}x#{height}"
    end

    def one_game
      say "a game with #{cabinet.sizing.name}"
      start_game
      pop_bright
      run_out_the_clock
    end

    def share
      wait(P::Style::GAME_OVER.tally.duration + 1.0)
      reach = show.share_reach
      click(reach.center_x, reach.center_y)
      shoot("share")
      key(:escape)
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

    def screens(width, height, phone)
      fit(width, height, phone)
      [DEFAULT, DEFAULT.toggled].each do |sizing|
        cabinet.sizing = sizing
        name = sizing == DEFAULT ? "default" : "other"
        show.open_settings
        shoot("settings-#{name}")
        show.back
        show.open_stats
        shoot("stats-#{name}")
        show.close_stats
        group(name)
      end
      cabinet.sizing = DEFAULT
    end

    def group(name)
      panel.open
      wait_for("the groups", within: 900) { panel.groups.groups.any? { it.join_code == code } }
      panel.press([:group_show, panel.groups.groups.find { it.join_code == code }.id], :touch, 0.0)
      wait_for("the standings", within: 900) { panel.group }
      shoot("group-#{name}")
      show.back
      show.back
    end

    def shoot(state, settle: 1.0)
      wait(settle)
      say "#{state} #{@size}: #{show.stats_note.inspect}"
      keep_screenshot("sizes-#{state}-#{@size}")
    end
  end
end
