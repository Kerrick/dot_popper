# frozen_string_literal: true

require_relative "presentation_helper"

class TutorTest < Minitest::Test
  include PresentationTest

  MISTAKE = Mistake.new(popped: 3, bright: 4)

  def test_it_teaches_a_few_times_and_remembers_across_sessions
    store = DotPopper::ScoreRecord::Memory.new
    tutor = Tutor.new(store, times: 2)

    assert_equal MISTAKE, tutor.lesson(MISTAKE)
    refute Tutor.new(store, times: 2).taught?
    assert_equal MISTAKE, tutor.lesson(MISTAKE)
    assert_nil tutor.lesson(MISTAKE)
    assert Tutor.new(store, times: 2).taught?
  end

  def test_a_player_taught_by_an_older_version_is_not_taught_again
    store = DotPopper::ScoreRecord::Memory.new
    store.write(Tutor::LEGACY)

    assert_nil Tutor.new(store, times: 2).lesson(MISTAKE)
  end

# Game Over points at the mistake only while its bright dot is still the
  # bright one, and its popped dot is there.
  def test_a_slip_can_be_pointed_at_only_while_its_bright_dot_is_still_bright
    popped = DotPopper::Dot.new(id: 3, x: 100, y: 100, velocity_x: 0, velocity_y: 0, radius: R, popped: true)
    bright = DotPopper::Dot.new(id: 4, x: 130, y: 100, velocity_x: 0, velocity_y: 0, radius: R)
    dots = DotPopper::Stack.new(dots: [popped, bright])
  
    assert_equal MISTAKE, MISTAKE.among(dots)
    assert_nil MISTAKE.among(dots.replace(bright.pop)), "once it was popped, nothing shows which it was"
    assert_nil MISTAKE.among(DotPopper::Stack.new(dots: [bright])), "nor without the popped dot"
  end
  
  def test_its_wrong_tap_replays_a_few_times_after_the_score_has_counted
    style = Style::LESSON
    assert style.replay_due?(0, 0.0)
    refute style.replay_due?(1, style.every - 0.01)
    assert style.replay_due?(1, style.every)
    refute style.replay_due?(style.replays, 100.0), "then the pile is left in peace"
  end
  
  def test_a_damaged_count_starts_over
    store = DotPopper::ScoreRecord::Memory.new
    store.write("lots")

    assert_equal 0, Tutor.new(store, times: 2).shown
  end
end
