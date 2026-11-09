# frozen_string_literal: true

module DotPopperGui
  # "How to play" on the title: drawn beside the mute button with the
  # help sign on it, and pressed, the tutorial at
  # once, though the director never opens it on a Play. It plays as a
  # first Play's does: the guide taps the bright dot, and the player's tap
  # pops it. Skipped, a game starts; back on the title, H opens it again.
  #
  # It plays with the mouse, or with DOT_POPPER_GUI_INPUT=touch, a finger,
  # or with DOT_POPPER_GUI_INPUT=gamepad, Y.
  class HowToPlayScenario < Scenario
    scenario :how_to_play

    T = DotPopper::Presentation::Tutorial

    def play
      check(show.home?, "the game opens on the title")
      touch(layout.safe.x + 4, layout.safe.y + 4) if hand == "touch" # a finger in hand, so the tutorial's guide is one
      wait(0.6)
      reach = show.reach_of(:how_to_play)
      check(reach, "the title offers How to play")
      lit = screenshot.lit_in(reach)
      check(lit >= 40, "How to play is drawn (#{lit} light pixels)")
      keep_screenshot(name("title"))
      press_it(reach)
      check(show.tutorial?, "How to play opens the tutorial at once")
      check(cabinet.state.is_a?(DotPopper::Cabinet::Home) && cabinet.game.nil?, "the game stays on its title meanwhile")
      wait_for("the tutorial's first beat", within: 900) { show.tutorial&.beat == :aim }
      wait(0.6)
      keep_screenshot(name("tutorial"))
      return skip_by_gamepad if hand == "gamepad"

      bright = show.tutorial.dots.find { it.id == T::BRIGHT }
      how.call(bright.x, bright.y)
      check_equal(:points, show.tutorial.beat, "a tap on the bright dot pops it")
      key(:escape)
      check(show.playing?, "Escape skips it, and the game starts")
      run_out_the_clock
      continue_to_home(how)
      key(:h)
      check(show.tutorial?, "H opens it again from the title")
    end

    private

    def hand = ENV.fetch("DOT_POPPER_GUI_INPUT", "mouse")
    def how = method(hand == "touch" ? :touch : :click)
    def name(what) = "how-to-play-#{hand}-#{layout.width.round}x#{layout.height.round}-#{what}"

    def press_it(reach)
      return pad(:y) if hand == "gamepad"

      how.call(reach.center_x, reach.center_y)
    end

    def skip_by_gamepad
      pad(:b)
      check(show.playing?, "a gamepad's B skips it")
    end
  end
end
