# frozen_string_literal: true

require_relative "presentation_helper"

class PileGrabTest < Minitest::Test
  include PresentationTest

  LOOK = GrabLook.new(slop: 0.25, hold: 0.15, follow: 0.05, fastest: 60.0, fling: 40.0, window: 0.1)

  def setup = @grabs = PileGrabs.new(LOOK)

  def press(key = :mouse, x = 100, y = 100, now: 0.0, ball: nil, heard: true)
    @grabs.press(key, x, y, now:, radius: R, heard:, ball:, center: ball && [x + 5, y])
  end

  def test_a_quick_still_press_is_a_click_on_a_ball_or_off_one
    press(ball: 3)
    assert_equal Click.new(x: 101.0, y: 100.0), @grabs.release(:mouse, 101, 100, now: 0.1)

    press
    assert_equal Click.new(x: 100.0, y: 100.0), @grabs.release(:mouse, 100, 100, now: 0.1)
  end

  # A gamepad's A is a pointer too, at its cursor, which the shell moves
  # every frame it is held, even standing still: a quick press goes on,
  # and a hold on a dot drags it and throws it at the cursor's speed.
  def test_a_gamepad_held_on_a_ball_drags_it_and_throws_it_with_the_cursor
    press(:gamepad)
    assert_instance_of Click, @grabs.release(:gamepad, 100, 100, now: 0.1)

    press(:gamepad, ball: 3)
    12.times { @grabs.move(:gamepad, 100, 100, now: it / 60.0) }
    @grabs.update(12 / 60.0)
    assert_equal [3], @grabs.drags.map(&:ball)

    (1..6).each { @grabs.move(:gamepad, 100 + (10 * it), 100, now: (12 + it) / 60.0) }
    fling = @grabs.release(:gamepad, 160, 100, now: 18 / 60.0)
    assert_equal 3, fling.ball
    assert_in_delta 600.0, fling.velocity[0], 100.0, "about the cursor's 600 units a second"
  end

  def test_a_click_off_the_pile_goes_on_however_long_it_is_held
    press
    @grabs.update(2.0)

    assert_instance_of Click, @grabs.release(:mouse, 100, 100, now: 2.0)
  end

  # A press the game would have ignored, in Game Over's grace, stays
  # ignored when it lets go after the grace.
  def test_a_press_in_the_grace_is_no_click
    press(heard: false)

    assert_nil @grabs.release(:mouse, 100, 100, now: 0.05)
  end

  def test_wandering_past_the_slop_on_a_ball_drags_it
    press(ball: 3)
    @grabs.move(:mouse, 100 + (0.2 * R), 100, now: 0.02)
    assert_empty @grabs.drags

    @grabs.move(:mouse, 100 + (0.3 * R), 100, now: 0.04)
    assert_equal [3], @grabs.drags.map(&:ball)
  end

  def test_holding_a_ball_long_enough_drags_it
    press(ball: 3)
    @grabs.update(0.1)
    assert_empty @grabs.drags

    @grabs.update(0.16)
    assert_equal [3], @grabs.drags.map(&:ball)
  end

  def test_a_swipe_off_the_pile_does_nothing
    press
    @grabs.move(:mouse, 100 + R, 100, now: 0.05)

    assert_nil @grabs.release(:mouse, 100 + R, 100, now: 0.06)
    assert_empty @grabs.drags
  end

  def test_letting_go_of_a_drag_throws_the_ball_at_the_pointers_speed
    press(ball: 3)
    (1..10).each { @grabs.move(:mouse, 100 + (it * 10), 100, now: it * 0.02) }
    fling = @grabs.release(:mouse, 210, 100, now: 0.22)

    assert_equal 3, fling.ball
    assert_in_delta 500.0, fling.velocity[0], 1.0
    assert_in_delta 0.0, fling.velocity[1]
  end

  def test_a_drag_stopped_before_it_lets_go_is_dropped_still
    press(ball: 3)
    @grabs.move(:mouse, 200, 100, now: 0.1)
    fling = @grabs.release(:mouse, 200, 100, now: 1.0)

    assert_in_delta 0.0, fling.velocity[0]
  end

  def test_a_throw_is_never_faster_than_the_fling
    press(ball: 3)
    @grabs.move(:mouse, 100 + (100 * R), 100, now: 0.01)
    fling = @grabs.release(:mouse, 100 + (100 * R), 100, now: 0.02)

    assert_in_delta LOOK.fling * R, Math.hypot(*fling.velocity)
  end

  def test_a_held_ball_is_pulled_to_the_pointer_where_it_was_held
    press(ball: 3)
    @grabs.move(:mouse, 120, 100, now: 0.2)
    grab = @grabs.drags.first

    assert_equal [125.0, 100.0], grab.target
    assert_equal [100.0, 0.0], grab.pull([120.0, 100.0], LOOK)
    assert_in_delta LOOK.fastest * R, Math.hypot(*grab.pull([125.0 - (100 * R), 100.0], LOOK))
  end

  def test_each_finger_drags_a_ball_of_its_own
    press(1, ball: 3)
    press(2, 300, 100, ball: 4)
    @grabs.update(0.2)

    assert_equal [3, 4], @grabs.drags.map(&:ball)
  end

  def test_a_ball_already_held_cannot_be_taken
    press(1, ball: 3)
    press(2, ball: 3)
    @grabs.update(0.2)

    assert_equal 1, @grabs.drags.size
  end

  def test_no_click_goes_on_while_another_finger_drags
    press(1, ball: 3)
    @grabs.update(0.2)
    press(2, 300, 300, now: 0.2)

    assert_nil @grabs.release(2, 300, 300, now: 0.25)
  end

  # iOS can cancel a touch without a touchreleased: the same id pressed
  # again lets its old ball go first.
  def test_a_pointer_pressed_again_lets_its_ball_go
    press(1, ball: 3)
    @grabs.update(0.2)

    assert_equal Fling.new(ball: 3, velocity: nil), press(1, 50, 50, now: 0.3)
    assert_empty @grabs.drags
  end

  def test_dropping_every_pointer_lets_every_ball_go
    press(1, ball: 3)
    press(2, 300, 100, ball: 4)
    press(3, 500, 100)
    @grabs.update(0.2)

    assert_equal [3, 4], @grabs.drop_all.map(&:ball)
    assert_nil @grabs.release(3, 500, 100, now: 0.3)
  end

  def test_a_release_with_no_press_is_nothing
    assert_nil @grabs.release(:mouse, 1, 2, now: 0.0)
    assert_nil @grabs.move(:mouse, 1, 2, now: 0.0)
  end
end
