# frozen_string_literal: true

module DotPopperGui
  # Dragging the game-over pile with a gamepad, as
  # DOT_POPPER_FAKE_GAMEPAD=1 and DOT_POPPER_FAKE_DRAG=0.5,0.9,0.3,0.3
  # make it: A held on the dot at the bottom drags it up and to the left
  # and lets it go, and Game Over stays; then a quick press of A goes on.
  class PileGamepadScenario < Scenario
    scenario :pile_gamepad

    def play
      # Under X11 the pointer resting over a window as it opens moves the
      # mouse, which the words follow, so the pad speaks first.
      pad(:dpup)
      check_equal("Play (A)", words.play, "the words name the gamepad's button")
      pad(:start)
      check(show.playing?, "Start starts a game")
      run_out_the_clock
      high = layout.height * 0.5
      wait_for("the held dot dragged up", within: 300) { pile.stack.any? { it.y < high } }
      check(true, "A held on a dot drags it up")
      check_warm_pixel
      wait(1.5)
      check(show.finished?, "the drag stays on Game Over")
      pad(:a)
      check(show.title?, "a quick press of A goes on to the title")
    end
  end
end
