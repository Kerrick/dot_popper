# frozen_string_literal: true

module DotPopperGui
  # The window changing under a round and under Game Over: shrunk and
  # grown by the system, switched to fullscreen and back by F11 and by
  # Lota::Window, and every dot kept on screen each time. The game-over
  # pile refits to a window shrunk under it.
  class ResizingScenario < Scenario
    scenario :resizing

    SIZES = [[800, 500], [1100, 700], [500, 400], [1200, 800]].freeze

    def play
      start_round
      pop_fresh
      SIZES.each do |width, height|
        resize(width, height)
        check_round_fits
      end
      key(:f11)
      settled_window("F11 fullscreen") { L::Window.fullscreen.first }
      check_round_fits
      key(:f11)
      settled_window("F11 back to a window") { !L::Window.fullscreen.first }
      check_round_fits
      fullscreen(true)
      fullscreen(false)
      check_round_fits
      run_out_the_clock
      pile_refits
      continue_to_title
    end

    private

    def check_round_fits
      width, height = L::Graphics.dimensions
      check_equal([width, height], [round.field.width, round.field.height], "the round's field is the window")
      check(round.dots.all? { inside_window?(it) }, "every dot is inside the #{width}x#{height} window")
      check_hud_drawn
    end

    # The pile settles on the floor, then the window shrinks under it.
    def pile_refits
      wait(1.5)
      resize(1200, 450)
      wait(0.5)
      stack = pile.stack
      inside = stack.all? { it.x.between?(0, layout.width) && it.y.between?(0, layout.height) }
      check(inside, "the pile's dots are all inside the shrunk window")
      check_warm_pixel
      resize(1200, 800)
      wait(0.5)
      check(pile.stack.all? { it.y.between?(0, layout.height) }, "the pile's dots stay in the grown window")
    end
  end
end
