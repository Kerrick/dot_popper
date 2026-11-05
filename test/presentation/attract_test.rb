# frozen_string_literal: true

require_relative "presentation_helper"

class AttractTest < Minitest::Test
  include PresentationTest

  def test_popped_dots_drift_over_fresh_ones
    attract = Attract.spawn(field, Look::TITLE)
    tops = attract.dots.map(&:popped?)

    assert_equal Look::TITLE.dots, tops.size
    assert_equal tops.sort_by { it ? 0 : 1 }, tops
  end

  def test_they_drift_and_stay_on_screen
    attract = Attract.spawn(field, Look::TITLE)
    moved = attract.update(0.5).refit(field(300, 200))

    refute_equal attract.dots.map(&:x), moved.dots.map(&:x)
    moved.dots.each { assert_operator it.x, :<=, 300 - R }
  end
end
