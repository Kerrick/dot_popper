# frozen_string_literal: true

require_relative "presentation_helper"

class PillFillTest < Minitest::Test
  include DotPopper::Presentation

  RECT = Rect.new(x: 100.0, y: 50.0, width: 300.0, height: 60.0)

  # The maintainer saw the hold-to-clear fill's first frames stand out
  # above and below the button's rounded end.
  def test_the_fill_never_leaves_the_pill_at_any_amount
    (0..100).each do |percent|
      PillFill.new(rect: RECT, amount: percent / 100.0).outline.each_slice(2) do |x, y|
        assert inside?(x, y), "#{percent}%: (#{x}, #{y}) is outside the pill"
      end
    end
  end

  def test_a_small_fill_is_shorter_than_the_pill_and_a_full_one_reaches_across
    sliver = PillFill.new(rect: RECT, amount: 0.02).outline.each_slice(2).map(&:last)
    full = PillFill.new(rect: RECT, amount: 1.0).outline.each_slice(2).to_a

    assert_operator sliver.max - sliver.min, :<, RECT.height * 0.7
    assert_in_delta RECT.x, full.map(&:first).min, 1e-9
    assert_in_delta RECT.right, full.map(&:first).max, 1e-9
    assert_in_delta RECT.height, full.map(&:last).max - full.map(&:last).min, 1e-9
  end

  def test_nothing_to_fill_has_no_outline
    assert_empty PillFill.new(rect: RECT, amount: 0.0).outline
  end

  private

  def inside?(x, y)
    r = RECT.height / 2.0
    cx = x.clamp(RECT.x + r, RECT.right - r)
    Math.hypot(x - cx, y - RECT.center_y) <= r + 1e-9
  end
end
