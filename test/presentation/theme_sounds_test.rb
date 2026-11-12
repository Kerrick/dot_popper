# frozen_string_literal: true

require_relative "presentation_helper"

# What each theme plays in place of the ordinary sounds (Theme#sounds,
# Shell::Speaker#use). A bonus dot's pop plays the pop and then
# :bonus_pop over it (Show#bonus_popped), so a theme's :bonus_pop must
# not bring the ordinary pop back under the theme's own.
class ThemeSoundsTest < Minitest::Test
  include PresentationTest

  def test_the_ordinary_theme_plays_the_ordinary_sounds
    assert_empty Style::THEMES.first.sounds
  end

  def test_every_theme_plays_its_own_pop_and_mistake
    Style::THEMES.reject(&:ordinary?).each do |theme|
      assert_includes theme.sounds.keys, :pop, theme.key
      assert_includes theme.sounds.keys, :bonk, theme.key
    end
  end

  def test_no_theme_plays_the_ordinary_pop_under_its_own_bonus_pop
    ordinary = Style::PATCHES[:pop].notes.reject { it.wave == :noise }
    Style::THEMES.reject(&:ordinary?).each do |theme|
      bonus_pop = Style::PATCHES.merge(theme.sounds).fetch(:bonus_pop) # as Speaker#use merges them

      assert_empty bonus_pop.notes & ordinary, theme.key
    end
  end

  def test_the_ordinary_bonus_pop_sounds_as_it_always_has
    samples = Synth.render(Style::PATCHES[:bonus_pop])

    assert_equal 19_845, samples.size
    assert_in_delta 630.0235451567336, samples.sum { it * it }, 1e-6
  end
end
