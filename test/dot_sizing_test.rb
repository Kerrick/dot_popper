# frozen_string_literal: true

require "test_helper"

class DotSizingTest < Minitest::Test
  include DotPopperTest
  DotSizing = DotPopper::DotSizing
  SizeClass = DotPopper::SizeClass

  def test_the_same_size_everywhere_is_the_specs_radius
    phone = field(395, 850)

    assert_same phone, DotSizing::BIGGER_OR_SMALLER.fit(phone)
    assert_equal SizeClass::SMALL, DotSizing::BIGGER_OR_SMALLER.size_class(phone)
  end

  def test_standard_fits_each_screens_radius_and_is_a_class_of_its_own
    standard = DotSizing::STANDARD.fit(field(3010, 1690))

    assert_equal [3010.0, 1690.0], [standard.width, standard.height]
    assert_in_delta 115.1, standard.radius, 0.1
    assert_equal SizeClass::STANDARD, DotSizing::STANDARD.size_class(field(395, 850))
    assert_equal SizeClass::STANDARD, DotSizing::STANDARD.size_class(field(3010, 1690))
  end

  def test_it_toggles_and_saves_and_reads_leniently
    assert_equal DotSizing::STANDARD, DotSizing::BIGGER_OR_SMALLER.toggled
    assert_equal DotSizing::BIGGER_OR_SMALLER, DotSizing::STANDARD.toggled
    assert_equal DotSizing::STANDARD, DotSizing.parse("#{DotSizing::STANDARD.to_text}\n")
    assert_equal DotSizing::BIGGER_OR_SMALLER, DotSizing.parse("#{DotSizing::BIGGER_OR_SMALLER.to_text}\n")
  end

  # The save says "standard", the screens' word for the bigger or smaller
  # size when it was written. Before, it said "same", which a player who
  # chose that size keeps.
  def test_the_bigger_or_smaller_size_is_saved_as_standard_and_read_by_its_earlier_name_too
    assert_equal "standard", DotSizing::BIGGER_OR_SMALLER.to_text
    assert_equal DotSizing::BIGGER_OR_SMALLER, DotSizing.parse("standard\n")
    assert_equal DotSizing::BIGGER_OR_SMALLER, DotSizing.parse("same\n")
  end

  # A player who never chose gets standard dots; one who chose
  # the bigger or smaller size (written only by a choice) keeps it.
  def test_a_player_who_never_chose_gets_standard_dots
    assert_equal DotSizing::STANDARD, DotSizing::DEFAULT
    assert_equal DotSizing::DEFAULT, DotSizing.parse(nil)
    assert_equal DotSizing::DEFAULT, DotSizing.parse("")
    assert_equal DotSizing::DEFAULT, DotSizing.parse("huge")
    assert_equal DotSizing::BIGGER_OR_SMALLER, DotSizing.parse("same")
  end
end
