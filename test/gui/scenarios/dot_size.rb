# frozen_string_literal: true

module DotPopperGui
  # The choice of dot size on a narrow window (DOT_POPPER_WINDOW=400x850),
  # where the two sizes differ: the second segment chosen with a click,
  # remembered, and the next round played with dots sized to the window.
  class DotSizeScenario < Scenario
    scenario :dot_size

    R = DotPopper::Rules

    def play
      check_equal([400, 850], L::Graphics.dimensions, "the window opens at DOT_POPPER_WINDOW's size")
      quick_round
      check(show.sizing_offered?, "the title offers the dot size on a narrow window")
      check(!game.sizing.sized_to_screen?, "standard dots to begin with")
      _, second = show.sizing_reaches.last
      click(second.center_x, second.center_y)
      check(game.sizing.sized_to_screen?, "a click on the second segment sizes dots to the screen")
      check_equal(game.sizing.to_text, File.read(saved("dot_size.txt")), "dot_size.txt remembers the choice")
      start_round
      check_close(fitted_radius, round.field.radius, "the next round's dots are sized to the window")
      check_close(fitted_radius, fresh_dot.radius, "its fresh dot has that radius")
      wait(0.5)
      check_fresh_pixel(fresh_dot)
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
