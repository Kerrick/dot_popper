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

  def test_it_finds_the_bright_dot_a_tap_on_a_popped_one_was_too_soon_for
    popped = dot(400, 300, popped: true)
    hidden = dot(440, 300)
    stack = DotPopper::Stack.new(dots: [popped, hidden])

    assert_equal hidden, stack.bright_beneath(popped, 380, 300)
  end

  def test_a_bright_dot_elsewhere_was_not_under_there
    popped = dot(400, 300, popped: true)
    stack = DotPopper::Stack.new(dots: [popped, dot(600, 300)])

    assert_nil stack.bright_beneath(popped, 400, 300)
  end

  def test_only_a_bright_dot_beneath_the_tapped_one_counts
    bright_above = dot(420, 300)
    popped = dot(400, 300, popped: true)
    popped_below = dot(410, 300, popped: true)
    stack = DotPopper::Stack.new(dots: [bright_above, popped, popped_below])

    assert_nil stack.bright_beneath(popped, 400, 300)
  end
end
