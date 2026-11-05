# frozen_string_literal: true

require_relative "presentation_helper"

class HoldToConfirmTest < Minitest::Test
  include PresentationTest

  def setup = @hold = HoldToConfirm.idle(2.0)

  def test_it_is_done_only_once_held_for_its_whole_time
    held = @hold.press(:mouse, 1.0)

    refute held.done?(2.9)
    assert_in_delta 0.5, held.progress(2.0)
    assert held.done?(3.0)
    assert_in_delta 1.0, held.progress(9.0)
    assert_in_delta 0.0, @hold.progress(9.0)
  end

  def test_letting_go_too_soon_does_nothing_but_leave_a_hint
    let_go = @hold.press(3, 1.0).release(3, 2.5)

    refute let_go.held?
    refute let_go.done?(10.0)
    assert_in_delta 0.5, let_go.let_go_ago(3.0)
    assert_nil @hold.let_go_ago(3.0)
  end

  def test_only_what_holds_it_can_let_it_go
    held = @hold.press(1, 0.0)

    assert_equal held, held.release(2, 1.0), "another finger"
    assert_equal held, held.release(:mouse, 1.0)
    assert_equal held, held.press(2, 1.0), "a second press adds nothing"
    assert held.done?(2.0)
  end

  def test_cancelling_forgets_the_hold_and_the_hint
    assert_equal @hold, @hold.press(:y, 0.0).cancel
    assert_equal @hold, @hold.press(:y, 0.0).release(:y, 0.1).cancel
  end

  def test_undo_is_offered_for_its_time
    offer = UndoOffer.new(cleared: nil, at: 5.0, seconds: 10.0)

    assert offer.open?(14.9)
    refute offer.open?(15.0)
    assert_in_delta 0.75, offer.left(7.5)
  end
end
