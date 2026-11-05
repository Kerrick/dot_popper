# frozen_string_literal: true

require_relative "presentation_helper"

class ShotScheduleTest < Minitest::Test
  include PresentationTest

  def test_shots_are_numbered_in_the_order_written
    schedule = ShotSchedule.parse("0.5, 3,oops,6.5")

    assert_equal [0.5, 3.0, 6.5], schedule.times
    assert_equal [1], schedule.due(0.4, 0.6)
    assert_equal [2, 3], schedule.due(0.6, 7)
    assert_empty schedule.due(7, 8)
  end

  def test_no_setting_means_no_shots
    assert_predicate ShotSchedule.parse(nil), :empty?
  end
end
