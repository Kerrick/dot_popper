# frozen_string_literal: true

require_relative "presentation_helper"

# Every theme the game can use, held to the ordinary theme's own standards
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

  def test_every_bright_color_is_far_lighter_than_every_popped_color
    each_style do |name, palette|
      bright = [palette.bright_light, palette.bright_body, palette.bright_deep, palette.bright_bounce]
      popped = [palette.popped_top, palette.popped_bottom, palette.popped_crater]

      bright.product(popped).each { |light, dark| assert_operator light.contrast(dark), :>=, 2.5, name }
      assert_operator palette.bright_body.contrast(palette.popped_lip), :>=, 3.0, name
      assert_operator palette.bright_body.contrast(palette.popped_top), :>=, 4.5, name
      assert_operator palette.bright_body.luminance - palette.popped_rim.luminance, :>=, 0.15, name
    end
  end

  def test_a_bright_dot_stands_out_from_the_night_and_a_popped_one_still_shows
    each_style do |name, palette|
      assert_operator palette.bright_body.contrast(palette.ink_top), :>=, 7.0, name
      assert_operator palette.popped_rim.contrast(palette.ink_top), :>=, 3.0, name
      assert_operator palette.popped_top.luminance, :>, palette.ink_top.luminance, name
    end
  end

  # A popped dot lies over the bright ones, and its rim must show against
  # a bright dot's light edge, or a bright dot's place in the stack is lost.
  def test_a_popped_dot_over_a_bright_one_shows_its_edge
    each_style do |name, palette|
      assert_operator palette.popped_rim.contrast(palette.bright_rim), :>=, 2.5, name
      assert_operator palette.bright_rim.contrast(palette.popped_top), :>=, 4.5, name
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

  # A dot shader is told which dot it draws only through its seed. A dot
  # keeps its seed for its whole life, so it is the same dot after its pop
  # as before, with the same face and outline, while each dot may be a
  # little its own. That popped dots still never differ in color,
  # lightness or size is test/gui/scenarios/popped_dots.rb's to check,
  # since a shader draws them.
  def test_a_dot_keeps_its_seed_through_its_pop
    dots = (1..40).map { DotPopper::Dot.new(id: it, x: 0, y: 0, velocity_x: 0, velocity_y: 0, radius: 1, popped: false, bonus: false) }

    dots.each { assert_equal Style::DOT.seed(it), Style::DOT.seed(it.pop) }
    assert_equal 40, dots.map { Style::DOT.seed(it.pop) }.uniq.size
  end

  # Nor can a theme's dot shader tell one dot from another by where it
  # is on the screen.
  def test_no_dot_shader_reads_where_on_the_screen_it_draws
    shaders = THEMES.filter_map(&:art).map { File.read("assets/shaders/themes/#{it.dot}.glsl") } << File.read("assets/shaders/dot.glsl")
    shaders.each do |source|
      body = source.gsub(%r{//.*}, "").sub(/vec4 effect\([^)]*\)/, "")

      refute_match(/\bscreen\b|gl_FragCoord|love_PixelCoord/, body)
    end
  end

  private

  def each_style = THEMES.each { yield it.key, it.palette }
end
