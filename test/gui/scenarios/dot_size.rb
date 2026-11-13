# frozen_string_literal: true

module DotPopperGui
  # The choice of dot size on a narrow window (DOT_POPPER_WINDOW=400x850),
  # where the two sizes differ: a new player's first game with dots sized
  # to the window (Standard), then the second segment, the bigger or smaller size
  # ("Bigger" there), chosen with a click, remembered, and the next game
  # played with it.
  class DotSizeScenario < Scenario
    scenario :dot_size

    R = DotPopper::Rules

    def play
      check_equal([400, 850], L::Graphics.dimensions, "the window opens at DOT_POPPER_WINDOW's size")
      check(cabinet.sizing.standard?, "a new player's dots are standard")
      check(!File.exist?(saved("dot_size.txt")), "nothing is saved before the player chooses")
      start_game
      check_close(standard_radius, game.field.radius, "the first game's dots are standard for the window")
      check_close(standard_radius, bright_dot.radius, "its bright dot has that radius")
      wait(0.5)
      check_bright_pixel(bright_dot)
      run_out_the_clock
      continue_to_home
      check(show.sizing_offered?, "Settings offers the dot size on a narrow window")
      settings = show.reach_of(:settings)
      click(settings.center_x, settings.center_y)
      second = show.reach_of(DotPopper::DotSizing::BIGGER_OR_SMALLER) or fail!("Settings offers no bigger or smaller size")
      click(second.center_x, second.center_y)
      check(!cabinet.sizing.standard?, "a click on the second segment picks the bigger or smaller size")
      check_equal(cabinet.sizing.to_text, File.read(saved("dot_size.txt")), "dot_size.txt remembers the choice")
      key(:escape)
      start_game
      check_close(R::RADIUS, game.field.radius, "the next game's dots are the bigger or smaller size")
    end

    private

    # The rules' radius for a 400 by 850 window: the field 384 square
    # radii, but never under 30 units.
    def standard_radius
      width, height = L::Graphics.dimensions
      Math.sqrt(width * height / R::STANDARD_AREA.to_f).clamp(R::SMALLEST_STANDARD_RADIUS.to_f,
                                                              [width, height].min * R::LARGEST_STANDARD_SHARE)
    end
  end
end
