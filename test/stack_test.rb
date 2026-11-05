# frozen_string_literal: true

require "test_helper"

class StackTest < Minitest::Test
  include DotPopperTest

  def test_each_new_dot_goes_underneath_every_dot_already_there
    first, second, third = dot(1, 1), dot(2, 2), dot(3, 3)
    stack = DotPopper::Stack.new.slide_under(first).slide_under(second).slide_under(third)

    assert_equal [first, second, third], stack.to_a
    assert_equal [third, second, first], stack.bottom_up.to_a
  end

  def test_a_point_reaches_only_the_topmost_dot_there
    older = dot(400, 300)
    newer = dot(420, 300)
    stack = DotPopper::Stack.new(dots: [older, newer])

    assert_equal older, stack.top_at(410, 300)
    assert_equal newer, stack.top_at(465, 300) # only the newer reaches here
    assert_nil stack.top_at(100, 100)
  end

  def test_replacing_a_dot_keeps_its_place_in_the_stack
    above, target, below = dot(1, 1), dot(2, 2), dot(3, 3)
    stack = DotPopper::Stack.new(dots: [above, target, below])

    replaced = stack.replace(target.pop)

    assert_equal [false, true, false], replaced.map(&:popped?)
    refute stack.to_a[1].popped?, "a stack is a value too"
  end
end
