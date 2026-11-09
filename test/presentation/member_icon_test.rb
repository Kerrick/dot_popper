# frozen_string_literal: true

require_relative "presentation_helper"

class MemberIconTest < Minitest::Test
  Icon = DotPopper::Presentation::MemberIcon

  def structure(group_id, number) = Icon.pattern(group_id, number).first(3)

  def test_an_icon_is_the_same_every_time
    assert_equal Icon.of(42, 3), Icon.of(42, 3)
    assert_equal Icon.of("a-b", 3), Icon.of("a-b", 3)
  end

  def test_groups_differ
    refute_equal Icon.of(1, 1).shapes, Icon.of(2, 1).shapes
  end

  def test_any_eight_members_of_a_group_differ_by_structure_not_only_hue
    [1, 2, 99, "abc-d", 123_456].each do |group|
      (1..200).each_slice(8) do |numbers|
        assert_equal numbers.size, numbers.map { structure(group, it) }.uniq.size, "group #{group}: #{numbers}"
      end
    end
  end

  def test_every_number_within_a_full_cycle_is_distinct
    numbers = (1..Icon::COMBINATIONS).to_a

    assert_equal numbers.size, numbers.map { structure(77, it) }.uniq.size
  end

  def test_large_numbers_work
    assert_kind_of Icon, Icon.of(5, 9_999_999_999)
  end

  def test_neighbours_differ_in_grayscale
    Icon::SCHEMES.first(Icon::DARK).each { assert_operator it[0].luminance, :<, 0.2 }
    Icon::SCHEMES.last(Icon::DARK).each { assert_operator it[0].luminance, :>, 0.45 }
  end

  def test_every_shape_stays_on_the_disc
    (1..60).each do |number|
      Icon.of(9, number).shapes.each do |shape|
        case shape
        in DotPopper::Presentation::IconDot then assert_operator Math.hypot(shape.x, shape.y) + shape.r, :<=, 1.0
        in DotPopper::Presentation::IconShape
          shape.points.each_slice(2) { |x, y| assert_operator Math.hypot(x, y), :<=, 1.0 }
        end
      end
    end
  end

  def test_the_crest_is_not_a_low_numbered_member
    (1..30).each { refute_equal Icon.of(3, -1).shapes, Icon.of(3, it).shapes }
    assert_equal Icon.of(3, -1), Icon.crest(3)
  end
end
