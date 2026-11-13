# frozen_string_literal: true

module DotPopperGui
  # Playing with the game-over pile by mouse, under a fake tilt
  # (DOT_POPPER_FAKE_TILT=0.6,0, which rolls it left): a dot dragged and
  # thrown, Game Over still showing after, then a plain click that goes
  # on to Home.
  class PileScenario < Scenario
    scenario :pile

    def play
      start_game
      3.times { pop_bright }
      run_out_the_clock
      wait(1.0)
      drag_and_throw
      wait(1.5)
      mean = pile.stack.sum(&:x) / pile.stack.size
      check(mean < layout.width * 0.4, "the tilt rolls the pile to the left (its middle at x #{mean.round})")
      check_warm_pixel
      continue_to_home
    end

    private

    def drag_and_throw
      dot = pile.stack.find { top?(it) } or fail!("no dot of the pile is on top")
      target = [layout.center_x, layout.height * 0.3]
      press(dot.x, dot.y)
      steps = 12
      1.upto(steps) do |i|
        move(dot.x + ((target[0] - dot.x) * i / steps), dot.y + ((target[1] - dot.y) * i / steps))
      end
      held = pile.center(dot.id)
      near = Math.hypot(held[0] - target[0], held[1] - target[1])
      check(near < dot.radius * 2, "the dragged dot follows the mouse (#{near.round} units from it)")
      release(*target)
      check(show.game_over?, "letting go of a drag stays on Game Over")
      before = pile.center(dot.id)
      frames(3)
      after = pile.center(dot.id)
      check(after[1] < before[1], "the thrown dot flies on up")
    end

    def top?(dot) = pile.stack.top_at(dot.x, dot.y)&.id == dot.id
  end
end
