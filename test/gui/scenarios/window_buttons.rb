# frozen_string_literal: true

module DotPopperGui
  # Settings' Display choice and Home's Quit on a desktop, by the mouse
  # alone, on a first Home and after a game: a click on Borderless fills
  # the screen, where the window's own buttons are gone, and a click on
  # Window puts the window back; a click on Quit asks Lota to quit at
  # once, with nothing asked first. The director holds that quit back and counts it, so the run
  # goes on to check it.
  #
  # The window manager switches the window, as the resizing scenario's
  # F11 does, so on an X display with none the switch never comes.
  class WindowButtonsScenario < Scenario
    scenario :window_buttons

    def play
      check(show.home?, "the game opens on Home")
      wait(0.6)
      check_drawn(:settings, "Settings")
      check_drawn(:quit, "Quit")
      keep_screenshot("window-buttons-#{layout.width.round}x#{layout.height.round}")
      quick_game
      wait(0.6)
      check_drawn(:quit, "after a game, with the large buttons, Quit")
      keep_screenshot("window-buttons-#{layout.width.round}x#{layout.height.round}-after-a-game")
      press_button(:settings)
      check(show.settings?, "Settings opens")
      reveal([:display, :borderless])
      wait(0.2)
      check_drawn([:display, :borderless], "Full screen is drawn as Borderless")
      press_button([:display, :borderless])
      settled_window("a click on Full screen fills the screen") { L::Window.fullscreen.first }
      check_equal(:borderless, show.window.display, "the button now says Window")
      keep_screenshot("window-buttons-fullscreen")
      reveal([:display, :window])
      press_button([:display, :window])
      settled_window("a click on Window puts the window back") { !L::Window.fullscreen.first }
      key(:escape)
      check_equal(0, Director.current.quits, "nothing has asked to quit")
      press_button(:quit)
      check_equal(1, Director.current.quits, "a click on Quit asks Lota to quit at once")
      check_equal(0.0, show.quit_prompt, "with nothing asked first")
    end

    private

    def press_button(name)
      reach = show.reach_of(name) or fail!("the title offers no #{name}")
      click(reach.center_x, reach.center_y)
    end

    def check_drawn(name, what)
      reach = show.reach_of(name) or fail!("the title offers no #{name}")
      lit = screenshot.lit_in(reach)
      check(lit >= 40, "#{what} is drawn (#{lit} light pixels)")
    end
  end
end
