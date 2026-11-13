# frozen_string_literal: true

require_relative "presentation_helper"

class SizingPreviewTest < Minitest::Test
  include PresentationTest

  FIXED = DotPopper::DotSizing::FIXED
  FITTED = DotPopper::DotSizing::SIZED_TO_SCREEN

  def preview(fitted, fixed: 50) = SizingPreview.new(fixed:, fitted:, style: Style::SIZING)
  def named(sizing, fitted) = Style::WORDS.sizing(sizing, preview(fitted))
  def note(sizing, fitted) = Style::WORDS.sizing_note(sizing, preview(fitted))

  # The default is "Standard" everywhere, and the other is named for
  # what a player sees it do here, next to it. The maintainer: "A player
  # sees only their own relative dot sizes: the smaller option, and the
  # bigger option." So on a phone the other reads "Bigger", and on a big
  # monitor "Smaller".
  def test_the_default_is_standard_and_the_other_is_named_for_what_it_does_here
    assert_equal ["Standard", "Bigger"], [named(FITTED, 30), named(FIXED, 30)]
    assert_equal ["Standard", "Bigger"], [named(FITTED, 44.9), named(FIXED, 44.9)]
    assert_equal ["Standard", "Smaller"], [named(FITTED, 55.1), named(FIXED, 55.1)]
    assert_equal ["Standard", "Smaller"], [named(FITTED, 97), named(FIXED, 97)]
  end

  # Under its name, each says what else it does: smaller dots leave more
  # room.
  def test_each_choice_says_how_much_room_it_leaves
    assert_equal ["More room", "Less room"], [note(FITTED, 30), note(FIXED, 30)]
    assert_equal ["Less room", "More room"], [note(FITTED, 97), note(FIXED, 97)]
  end

  # Within a tenth either way the two look alike, and Home leaves
  # the choice out.
  def test_sizes_within_a_tenth_of_each_other_are_not_worth_a_choice
    [45.1, 50, 54.9].each do
      assert_equal :alike, preview(it).effect
      refute preview(it).offered?
    end
    assert preview(44.9).offered?
    assert preview(55.1).offered?
  end

  def test_it_reads_this_screens_sizes
    assert_equal :smaller, SizingPreview.of(DotPopper::Field.new(400, 850, 50), Style::SIZING).effect
    assert_equal :bigger, SizingPreview.of(DotPopper::Field.new(2400, 1500, 50), Style::SIZING).effect
    assert_equal :alike, SizingPreview.of(DotPopper::Field.new(1200, 800, 50), Style::SIZING).effect
  end

  # The icons stand in true proportion to the two sizes, as far as they
  # stay legible in a segment.
  def test_the_icons_are_in_proportion
    fixed = preview(30).icon(FIXED, 50)

    assert_in_delta 50 * Style::SIZING.icon, fixed
    assert_in_delta fixed * 0.6, preview(30).icon(FITTED, 50)
    assert_in_delta fixed * 1.5, preview(75).icon(FITTED, 50)
    assert_equal fixed, preview(97).icon(FIXED, 50), "the fixed size's icon never changes"
  end

  def test_the_icons_stay_legible_and_inside_their_segment
    smallest, largest = Style::SIZING.icons.minmax

    assert_in_delta 50 * Style::SIZING.icon * smallest, preview(5).icon(FITTED, 50)
    assert_in_delta 50 * Style::SIZING.icon * largest, preview(500).icon(FITTED, 50)
    assert_operator 2 * preview(500).icon(FITTED, 50), :<, 50, "the biggest dot fits in the segment"
    assert_operator preview(5).icon(FITTED, 44), :>=, 3, "the smallest is still a dot"
  end
end
