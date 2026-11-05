# frozen_string_literal: true

require "test_helper"

class DotSizingTest < Minitest::Test
  include DotPopperTest
  DotSizing = DotPopper::DotSizing
  SizeClass = DotPopper::SizeClass

  def test_the_same_size_everywhere_is_the_specs_fixed_radius
    phone = field(395, 850)

    assert_same phone, DotSizing::SAME_EVERYWHERE.fit(phone)
    assert_equal SizeClass::SMALL, DotSizing::SAME_EVERYWHERE.size_class(phone)
  end

  def test_sized_to_the_screen_fits_each_screens_radius_and_is_a_class_of_its_own
    fitted = DotSizing::SIZED_TO_SCREEN.fit(field(3010, 1690))

    assert_equal [3010.0, 1690.0], [fitted.width, fitted.height]
    assert_in_delta 115.1, fitted.radius, 0.1
    assert_equal SizeClass::FITTED, DotSizing::SIZED_TO_SCREEN.size_class(field(395, 850))
    assert_equal SizeClass::FITTED, DotSizing::SIZED_TO_SCREEN.size_class(field(3010, 1690))
  end

  def test_it_toggles_and_saves_and_reads_leniently
    assert_equal DotSizing::SIZED_TO_SCREEN, DotSizing::SAME_EVERYWHERE.toggled
    assert_equal DotSizing::SAME_EVERYWHERE, DotSizing::SIZED_TO_SCREEN.toggled
    assert_equal DotSizing::SIZED_TO_SCREEN, DotSizing.parse("#{DotSizing::SIZED_TO_SCREEN.to_text}\n")
    assert_equal DotSizing::SAME_EVERYWHERE, DotSizing.parse(nil)
    assert_equal DotSizing::SAME_EVERYWHERE, DotSizing.parse("huge")
  end
end
