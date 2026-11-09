# frozen_string_literal: true

require_relative "presentation_helper"

class ChatterTest < Minitest::Test
  Chatter = DotPopper::Presentation::Chatter
  LOOK = DotPopper::Presentation::Style::CHATTER

  def quiet = Chatter.quiet(LOOK)

  def test_a_first_press_is_heard
    _, dropped = quiet.press(1, 400, 300, at: 2.0)

    refute dropped
  end

  def test_a_second_press_hard_on_the_first_in_the_same_place_is_dropped
    chatter, = quiet.press(1, 400, 300, at: 2.0)
    _, dropped = chatter.press(1, 402, 301, at: 2.03)

    assert dropped
  end

  def test_a_quick_double_click_by_hand_is_heard
    chatter, = quiet.press(1, 400, 300, at: 2.0)
    _, dropped = chatter.press(1, 400, 300, at: 2.1)

    refute dropped
  end

  def test_a_press_somewhere_else_is_heard_however_soon
    chatter, = quiet.press(1, 400, 300, at: 2.0)
    _, dropped = chatter.press(1, 420, 300, at: 2.01)

    refute dropped
  end

  def test_another_button_is_heard_however_soon
    chatter, = quiet.press(1, 400, 300, at: 2.0)
    _, dropped = chatter.press(2, 400, 300, at: 2.01)

    refute dropped
  end

  def test_a_dropped_press_drops_its_release_and_no_other
    chatter, = quiet.press(1, 400, 300, at: 2.0)
    chatter, first = chatter.release(1)
    chatter, = chatter.press(1, 400, 300, at: 2.02)
    chatter, second = chatter.release(1)
    _, later = chatter.release(1)

    refute first
    assert second
    refute later
  end

  def test_a_run_of_chatter_is_dropped_whole
    chatter, = quiet.press(1, 400, 300, at: 2.0)
    chatter, = chatter.press(1, 400, 300, at: 2.04)
    _, dropped = chatter.press(1, 400, 300, at: 2.08)

    assert dropped
  end

  def test_a_release_that_never_came_drops_nothing_once_let_go
    chatter, = quiet.press(1, 400, 300, at: 2.0)
    chatter, = chatter.press(1, 400, 300, at: 2.02)
    _, dropped = chatter.let_go.release(1)

    refute dropped
  end

  def test_a_heard_press_stops_waiting_for_a_dropped_release
    chatter, = quiet.press(1, 400, 300, at: 2.0)
    chatter, = chatter.press(1, 400, 300, at: 2.02)
    chatter, = chatter.press(1, 400, 300, at: 3.0)
    _, dropped = chatter.release(1)

    refute dropped
  end

  def test_its_window_is_past_bounce_and_short_of_a_hand
    assert_operator LOOK.seconds, :>, 0.02
    assert_operator LOOK.seconds, :<, 0.07
  end
end
