# frozen_string_literal: true

module DotPopperGui
  # The choice of dot size on a narrow window (DOT_POPPER_WINDOW=400x850),
  # where the two sizes differ: a new player's first game with dots sized
  # to the window, then the second segment, Standard, chosen with a click,
  # remembered, and the next game played with the standard dots.
  class DotSizeScenario < Scenario
    scenario :dot_size

    R = DotPopper::Rules

    def play
      check_equal([400, 850], L::Graphics.dimensions, "the window opens at DOT_POPPER_WINDOW's size")
      check(cabinet.sizing.sized_to_screen?, "a new player's dots are sized to the screen")
      check(!File.exist?(saved("dot_size.txt")), "nothing is saved before the player chooses")
      start_game
      check_close(fitted_radius, game.field.radius, "the first game's dots are sized to the window")
      check_close(fitted_radius, fresh_dot.radius, "its fresh dot has that radius")
      wait(0.5)
      check_fresh_pixel(fresh_dot)
      run_out_the_clock
      continue_to_title
      check(show.sizing_offered?, "the title offers the dot size on a narrow window")
      sizing, second = show.sizing_reaches.last
      check_equal(DotPopper::DotSizing::STANDARD, sizing, "the second segment is Standard")
      click(second.center_x, second.center_y)
      check(!cabinet.sizing.sized_to_screen?, "a click on the second segment picks the standard size")
      check_equal(cabinet.sizing.to_text, File.read(saved("dot_size.txt")), "dot_size.txt remembers the choice")
      start_game
      check_close(R::RADIUS, game.field.radius, "the next game's dots are the standard size")
    end

    private

    # The rules' radius for a 400 by 850 window: the field 384 square
    # radii, but never under 30 units.
    def fitted_radius
      width, height = L::Graphics.dimensions
      Math.sqrt(width * height / R::FITTED_AREA.to_f).clamp(R::SMALLEST_FITTED_RADIUS.to_f,
                                                            [width, height].min * R::LARGEST_FITTED_SHARE)
    end
  end
end
