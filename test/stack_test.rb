# frozen_string_literal: true

require "test_helper"

class StackTest < Minitest::Test
  include DotPopperTest

  def test_each_new_dot_goes_underneath_every_dot_already_there
    stack = DotPopper::Stack.new
    first, second, third = stack.slide_under(dot(1, 1)), stack.slide_under(dot(2, 2)), stack.slide_under(dot(3, 3))

    assert_equal [first, second, third], stack.to_a
    assert_equal [third, second, first], stack.bottom_up.to_a
  end

  def test_a_point_reaches_only_the_topmost_dot_there
    stack = DotPopper::Stack.new
    older = stack.slide_under(dot(400, 300))
    newer = stack.slide_under(dot(420, 300))

    assert_same older, stack.top_at(410, 300)
    assert_same newer, stack.top_at(465, 300) # only the newer reaches here
    assert_nil stack.top_at(100, 100)
  end
end
