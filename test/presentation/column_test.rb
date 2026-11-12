# frozen_string_literal: true

require_relative "presentation_helper"

class ColumnTest < Minitest::Test
  include PresentationTest

  ROOM = Rect.new(x: 0, y: 100, width: 200, height: 300)

  def test_blocks_stack_as_a_group_centered_down_the_room_each_its_gap_below_the_last
    placed = Column.new(room: ROOM).place([Block.new(name: :a, height: 40, gap: 99, width: 80),
                                           Block.new(name: :b, height: 60, gap: 20, width: 120)])

    assert_equal Rect.new(x: 60.0, y: 190.0, width: 80, height: 40), placed[:a], "the first gap is left out"
    assert_equal Rect.new(x: 40.0, y: 250.0, width: 120, height: 60), placed[:b]
    assert_equal Rect.new(x: 40.0, y: 190.0, width: 120, height: 120), placed.bounds
    assert placed.fits?
  end

  def test_a_column_can_start_at_its_top
    placed = Column.new(room: ROOM, align: :top).place([Block.new(name: :a, height: 40)])

    assert_in_delta 100, placed[:a].y
  end

  def test_type_shrinks_to_the_largest_scale_that_fits
    placed = Column.new(room: ROOM).fit([1.0, 0.9, 0.8, 0.7]) { |scale| [Block.new(name: :a, height: 360 * scale)] }

    assert_in_delta 0.8, placed.scale
    assert placed.key?(:a)
  end

  def test_short_of_room_at_the_floor_the_least_needed_blocks_go_and_the_type_grows_back
    blocks = lambda do |scale|
      [Block.new(name: :score, height: 200 * scale), Block.new(name: :hint, height: 100 * scale, drop: 1),
       Block.new(name: :summary, height: 100 * scale, drop: 2), Block.new(name: :prompt, height: 50 * scale)]
    end
    placed = Column.new(room: ROOM).fit([1.0, 0.9, 0.8, 0.7], &blocks)

    refute placed.key?(:hint), "the lowest rank goes first"
    assert placed.key?(:summary), "and nothing more than needs to"
    assert_in_delta 0.8, placed.scale, 1e-9, "the type grows back as far as what is left allows"
    assert placed.fits?
  end

  def test_blocks_that_must_stay_stay_even_when_they_do_not_fit
    placed = Column.new(room: ROOM).fit([1.0]) do
      [Block.new(name: :score, height: 400), Block.new(name: :hint, height: 10, drop: 1)]
    end

    assert placed.key?(:score)
    refute placed.key?(:hint)
    refute placed.fits?
    assert_in_delta 100, placed[:score].y, 1e-9, "it starts at the room's top"
  end
end
