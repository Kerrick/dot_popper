# frozen_string_literal: true

require_relative "presentation_helper"

# Settings: Sound, the dot size where the two sizes look different, and
# on a computer the window's Display; a short window scrolls to the rest.
class SettingsTest < Minitest::Test
  include PresentationTest

  def setup
    @sizing_store = DotPopper::ScoreRecord::Memory.new
    @cabinet = DotPopper::Cabinet.new(field, random: Random.new(2))
    @show = new_show(cabinet: @cabinet, layout: layout, sounds: FakeSounds.new, radius: R, sizing_store: @sizing_store)
    @show.open_settings
  end

  # 800 by 600 fits a radius of about 35 with standard dots.
  def test_a_tap_on_a_dot_size_chooses_it_and_it_is_remembered
    refute @cabinet.sizing.standard?
    @show.tap(*middle(@show.reach_of(DotPopper::DotSizing::FIXED)))
    assert_nil @sizing_store.read, "the chosen one again changes nothing, so nothing is saved"

    @show.tap(*middle(@show.reach_of(DotPopper::DotSizing::STANDARD)))
    assert @cabinet.sizing.standard?
    assert_equal "fitted", @sizing_store.read, "dot_size.txt's word for the default, as every build wrote it"
    assert @show.settings?, "the tap never leaves Settings"
    assert_in_delta 35.4, @show.attract.dots.first.radius, 0.1, "Home's dots follow the choice"
    @show.back
    press_main
    assert_in_delta 35.4, @cabinet.game.field.radius, 0.1
  end

  def test_the_size_that_is_the_same_everywhere_saves_as_standard
    @cabinet.sizing = DotPopper::DotSizing::DEFAULT
    @show.tap(*middle(@show.reach_of(DotPopper::DotSizing::DEFAULT.toggled)))

    assert_equal "standard", @sizing_store.read, "dot_size.txt's word for it, as every build wrote it"
  end

  # On the 24 × 16 R window, the two sizes are the same, so
  # Settings leaves the choice out, and a shoulder button changes nothing.
  def test_where_the_sizes_look_alike_the_choice_is_not_offered
    cabinet = DotPopper::Cabinet.new(field(1200, 800), random: Random.new(2), sizing: DotPopper::DotSizing::STANDARD)
    show = new_show(cabinet:, layout: layout(1200, 800), sounds: FakeSounds.new, radius: R, sizing_store: @sizing_store)
    show.open_settings

    refute show.sizing_offered?
    assert_nil show.reach_of(DotPopper::DotSizing::FIXED)
    show.pad(:lb)
    assert cabinet.sizing.standard?, "the saved choice stays"
    assert_nil @sizing_store.read
  end

  # A player who saved the fixed size there is still offered the choice,
  # and Standard, once chosen, stays in view until Settings is left; the
  # next visit leaves the choice out again.
  def test_where_the_sizes_look_alike_a_saved_fixed_size_is_still_offered
    cabinet = DotPopper::Cabinet.new(field(1200, 800), random: Random.new(2), sizing: DotPopper::DotSizing::FIXED)
    show = new_show(cabinet:, layout: layout(1200, 800), sounds: FakeSounds.new, radius: R, sizing_store: @sizing_store)
    show.open_settings

    assert show.reach_of(DotPopper::DotSizing::STANDARD), "the choice shows while the fixed size is saved"
    show.tap(*middle(show.reach_of(DotPopper::DotSizing::STANDARD)))
    assert cabinet.sizing.standard?
    assert_equal "fitted", @sizing_store.read
    assert show.reach_of(DotPopper::DotSizing::FIXED), "the row stays under the finger while Settings is open"

    show.back
    show.open_settings
    assert_nil show.reach_of(DotPopper::DotSizing::FIXED), "the next visit leaves it out"
  end

  def test_a_short_window_scrolls_to_what_does_not_fit
    show = new_show(cabinet: @cabinet, layout: layout(400, 320), sounds: FakeSounds.new, radius: R, window: FakeWindow.new)
    show.open_settings
    assert_nil show.reach_of(:privacy), "Privacy is below the window"

    show.scroll_key(:end)
    assert show.reach_of(:privacy)
    assert_nil show.reach_of([:sound, true]), "Sound has scrolled away above"
  end

  private

  def middle(rect) = [rect.center_x, rect.center_y]
end
