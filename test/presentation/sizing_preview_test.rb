# frozen_string_literal: true

require_relative "presentation_helper"

class SizingPreviewTest < Minitest::Test
  include PresentationTest

  STANDARD = DotPopper::DotSizing::STANDARD
  FITTED = DotPopper::DotSizing::SIZED_TO_SCREEN

  def preview(fitted, standard: 50) = SizingPreview.new(standard:, fitted:, look: Look::SIZING)
  def note(sizing, fitted) = Look::WORDS.sizing_note(sizing, preview(fitted))

  # The first choice, the default, fits the screen; the second is the
  # standard size.
  def test_the_choices_are_named_the_same_on_every_screen
    assert_equal ["Fit the screen", "Standard"], DotPopper::Presentation::Show::SIZINGS.map { Look::WORDS.sizing(it) }
  end

  # Under its name, each says what it does on this screen.
  def test_each_choice_says_what_it_does_here
    assert_equal "Smaller, more room", note(FITTED, 30)
    assert_equal "Smaller, more room", note(FITTED, 44.9)
    assert_equal "Bigger, less room", note(FITTED, 55.1)
    assert_equal "Bigger, less room", note(FITTED, 97)
    assert_equal "Bigger, less room", note(STANDARD, 30), "on a phone, standard dots are the bigger ones"
    assert_equal "Smaller, more room", note(STANDARD, 97)
  end

  # Within a tenth either way the two look alike, and the title leaves
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
    assert_equal :smaller, SizingPreview.of(DotPopper::Field.new(400, 850, 50), Look::SIZING).effect
    assert_equal :bigger, SizingPreview.of(DotPopper::Field.new(2400, 1500, 50), Look::SIZING).effect
    assert_equal :alike, SizingPreview.of(DotPopper::Field.new(1200, 800, 50), Look::SIZING).effect
  end

  # The icons stand in true proportion to the two sizes, as far as they
  # stay legible in a segment.
  def test_the_icons_are_in_proportion
    standard = preview(30).icon(STANDARD, 50)

    assert_in_delta 50 * Look::SIZING.icon, standard
    assert_in_delta standard * 0.6, preview(30).icon(FITTED, 50)
    assert_in_delta standard * 1.5, preview(75).icon(FITTED, 50)
    assert_equal standard, preview(97).icon(STANDARD, 50), "the standard icon never changes"
  end

  def test_the_icons_stay_legible_and_inside_their_segment
    smallest, largest = Look::SIZING.icons.minmax

    assert_in_delta 50 * Look::SIZING.icon * smallest, preview(5).icon(FITTED, 50)
    assert_in_delta 50 * Look::SIZING.icon * largest, preview(500).icon(FITTED, 50)
    assert_operator 2 * preview(500).icon(FITTED, 50), :<, 50, "the biggest dot fits in the segment"
    assert_operator preview(5).icon(FITTED, 44), :>=, 3, "the smallest is still a dot"
  end
end
