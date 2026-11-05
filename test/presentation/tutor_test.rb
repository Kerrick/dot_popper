# frozen_string_literal: true

require_relative "presentation_helper"

class TutorTest < Minitest::Test
  include PresentationTest

  def test_it_teaches_a_few_times_and_remembers_across_sessions
    store = DotPopper::BestScore::Memory.new
    tutor = Tutor.new(store, times: 2)

    assert_equal Look::WORDS.covered, tutor.lesson(Look::WORDS.covered)
    refute Tutor.new(store, times: 2).taught?
    assert_equal Look::WORDS.covered, tutor.lesson(Look::WORDS.covered)
    assert_nil tutor.lesson(Look::WORDS.covered)
    assert Tutor.new(store, times: 2).taught?
  end

  def test_a_player_taught_by_an_older_version_is_not_taught_again
    store = DotPopper::BestScore::Memory.new
    store.write(Tutor::LEGACY)

    assert_nil Tutor.new(store, times: 2).lesson(Look::WORDS.covered)
  end

  def test_a_damaged_count_starts_over
    store = DotPopper::BestScore::Memory.new
    store.write("lots")

    assert_equal 0, Tutor.new(store, times: 2).shown
  end
end
