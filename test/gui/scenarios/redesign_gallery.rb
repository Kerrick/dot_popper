# frozen_string_literal: true

module DotPopperGui
  # Home and the screens it opens, kept as screenshots to compare with the
  # redesign's mocks at 1200x800, 400x850 and 850x400 (the last two as a
  # phone, by touch), and Home again with a controller's labels.
  # DOT_POPPER_GALLERY names the shots. Not part of rake test:gui: it is
  # for reviewing the screens.
  class RedesignGalleryScenario < Scenario
    scenario :redesign_gallery

    SIZES = [[1200, 800, false], [400, 850, true], [850, 400, true]].freeze
    P = DotPopper::Presentation

    def play
      keeper = show.instance_variable_get(:@theme_keeper)
      wait(0.5)
      keeper.told(keeper.arrival) until keeper.arrival.nil?
      @size = "1200x800"
      shoot("home-first", settle: 1.5)
      quick_game
      SIZES.each { |width, height, phone| screens(width, height, phone) }
      groups if show.pro? && show.group_panel.available?
    end

    # The friend groups' screens, against a local stand-in for the server
    # (script/group_stub.rb, named by DOT_POPPER_SERVER): the keypad, a
    # group with its code shown, its history, and the list.
    def groups
      panel = show.group_panel
      SIZES.each_with_index do |(width, height, phone), i|
        fit(width, height, phone)
        panel.open
        wait_for("the list", within: 900) { panel.groups.groups.any? || i.zero? }
        if i.zero?
          panel.press(:group_join_open, :touch, show.now)
          "123".each_char { panel.press([:code_digit, it], :touch, show.now) }
          shoot("join")
          "4567".each_char { panel.press([:code_digit, it], :touch, show.now) }
          panel.press(:code_submit, :touch, show.now)
          wait_for("the group", within: 900) { panel.page == :group }
          show.back
        end
        shoot("groups", settle: 1.5)
        panel.press([:group_show, panel.groups.groups.first.id], :touch, show.now)
        panel.press(:group_code, :touch, show.now)
        shoot("group", settle: 1.5)
        panel.press(:group_history, :touch, show.now)
        wait_for("the history", within: 900) { panel.history_entries.any? }
        shoot("history", settle: 1.5)
        show.back
        show.back
        show.back
      end
    end

    private

    def tag = ENV.fetch("DOT_POPPER_GALLERY", "redesign")

    def fit(width, height, phone)
      show.instance_variable_set(:@window, P::NoWindowControl.new) if phone
      resize(width, height) unless L::Graphics.dimensions == [width, height]
      show.input = phone ? P::InputKind::TOUCH : P::InputKind::MOUSE
      @size = "#{width}x#{height}"
    end

    def screens(width, height, phone)
      fit(width, height, phone)
      shoot("home")
      show.input = P::InputKind::GAMEPAD
      shoot("home-gamepad", settle: 0.3)
      show.input = phone ? P::InputKind::TOUCH : P::InputKind::MOUSE
      page(:open_settings, "settings")
      show.open_credits
      shoot("credits")
      show.back
      show.open_privacy
      shoot("privacy")
      show.back
      show.back
      page(:open_stats, "stats")
      show.back
      page(:open_themes, "themes")
      show.input = P::InputKind::GAMEPAD
      shoot("themes-gamepad", settle: 0.3)
      show.input = phone ? P::InputKind::TOUCH : P::InputKind::MOUSE
      show.back
      page(:open_achievements, "achievements")
      show.open_achievement(DotPopper::Achievement::IDS.first)
      shoot("ach-open")
      show.back
      show.back
      offers unless show.pro?
      game_over
    end

    # A Free player's offer of Pro, led by a theme and by an achievement.
    def offers
      show.open_themes
      show.use(show.themes.last)
      shoot("offer-themes")
      show.back
      show.back
      show.open_achievements
      show.open_achievement(:steady)
      show.press(:achievement_pro, 0, 0, :mouse)
      shoot("offer-achievements")
      show.back
      show.back
    end

    # Game Over with its lines, a met goal and, for Pro, a new achievement.
    def game_over
      start_game
      3.times { pop_fresh }
      run_out_the_clock
      lines = { goal_met: true }
      lines[:achievements] = [:sharpshooter] if show.pro?
      show.instance_variable_set(:@game_over, show.game_over.with(**lines))
      shoot("over", settle: 3.0)
      continue_to_home
    end

    def page(opener, name)
      show.public_send(opener)
      shoot(name)
    end

    def shoot(state, settle: 0.8)
      wait(settle)
      keep_screenshot("#{tag}-#{@size}-#{state}")
    end
  end
end
