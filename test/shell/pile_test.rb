# frozen_string_literal: true

require "test_helper"
require "dot_popper/presentation"
require "dot_popper/shell/pile"

# The Game Over pile's scale in Box2D's own units (Shell::Pile), which
# the presentation never sees.
class ShellPileTest < Minitest::Test
  def test_box2d_sees_a_dot_as_a_ball_about_a_meter_across
    r = DotPopper::Rules::RADIUS
    meters = r / DotPopper::Shell::Pile.meter_for(r)

    assert_operator meters, :>=, 0.1
    assert_operator meters, :<=, 1.0
  end
end
