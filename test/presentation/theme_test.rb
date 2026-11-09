# frozen_string_literal: true

require_relative "presentation_helper"

# Every look the game can wear, held to the ordinary theme's own standards
# (ColorTest): a bright dot told from a popped one by lightness and not
# hue alone, the stack's order kept visible, and the words readable.
class ThemeTest < Minitest::Test
  include PresentationTest

  THEMES = Style::THEMES

  def test_the_ordinary_style_comes_first_and_is_the_only_one_without_art
    assert_predicate THEMES.first, :ordinary?
    assert_same Style::PALETTE, THEMES.first.palette
    assert_equal [THEMES.first], THEMES.select(&:ordinary?)
    assert_equal THEMES.map(&:key).uniq, THEMES.map(&:key)
    THEMES.each { assert_predicate it, :frozen? }
  end

  def test_every_style_is_named_in_words
    THEMES.each { assert Style::WORDS.themes.key?(it.key), "#{it.key} has no name" }
  end

  def test_every_fresh_color_is_far_lighter_than_every_popped_color
    each_style do |name, palette|
      fresh = [palette.fresh_light, palette.fresh_body, palette.fresh_deep, palette.fresh_bounce]
      popped = [palette.popped_top, palette.popped_bottom, palette.popped_crater]

      fresh.product(popped).each { |light, dark| assert_operator light.contrast(dark), :>=, 2.5, name }
      assert_operator palette.fresh_body.contrast(palette.popped_lip), :>=, 3.0, name
      assert_operator palette.fresh_body.contrast(palette.popped_top), :>=, 4.5, name
      assert_operator palette.fresh_body.luminance - palette.popped_rim.luminance, :>=, 0.15, name
    end
  end

  def test_a_fresh_dot_stands_out_from_the_night_and_a_popped_one_still_shows
    each_style do |name, palette|
      assert_operator palette.fresh_body.contrast(palette.ink_top), :>=, 7.0, name
      assert_operator palette.popped_rim.contrast(palette.ink_top), :>=, 3.0, name
      assert_operator palette.popped_top.luminance, :>, palette.ink_top.luminance, name
    end
  end

  # A popped dot lies over the fresh ones, and its rim must show against
  # a fresh dot's bright edge, or a fresh dot's place in the stack is lost.
  def test_a_popped_dot_over_a_fresh_one_shows_its_edge
    each_style do |name, palette|
      assert_operator palette.popped_rim.contrast(palette.fresh_rim), :>=, 2.5, name
      assert_operator palette.fresh_rim.contrast(palette.popped_top), :>=, 4.5, name
      assert_operator palette.popped_lip.contrast(palette.popped_crater), :>=, 2.2, name
      assert_operator palette.alarm.contrast(palette.popped_top), :>=, 2.8, name
    end
  end

  def test_the_words_read_on_the_night
    each_style do |name, palette|
      [palette.cream, palette.soft, palette.gain, palette.alarm, palette.urgent].each do |color|
        assert_operator color.contrast(palette.ink_bottom), :>=, 4.5, name
      end
    end
  end

  def test_a_style_is_told_apart_from_another_by_more_than_one_color
    THEMES.combination(2) do |one, other|
      changed = one.palette.to_h.count { |job, color| color != other.palette.public_send(job) }

      assert_operator changed, :>=, 10, "#{one.key} and #{other.key}"
    end
  end

  private

  def each_style = THEMES.each { yield it.key, it.palette }
end
