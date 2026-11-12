# frozen_string_literal: true

require_relative "presentation_helper"

class SynthTest < Minitest::Test
  include PresentationTest

  def test_every_sound_is_audible_and_never_clips
    Style::PATCHES.each do |name, patch|
      samples = Synth.render(patch)

      assert_equal (patch.length * Synth::RATE).ceil, samples.size, name
      assert_in_delta Synth::PEAK, samples.map(&:abs).max, 1e-9, name
    end
  end

  def test_every_sound_ends_in_silence
    Style::PATCHES.each_value { assert_operator Synth.render(it).last.abs, :<, 0.05 }
  end

  def test_the_sounds_are_short
    Style::PATCHES.each { |name, patch| assert_operator patch.length, :<=, 1.0, name }
  end

  # A theme replaces only sounds the game plays, each held to the same
  # standards as the ordinary ones.
  def test_every_themes_sounds_are_the_games_and_held_to_the_same_standards
    Style::THEMES.filter_map(&:art).each do |art|
      art.sounds.each do |name, patch|
        label = "#{art.dot} #{name}"
        samples = Synth.render(patch)

        assert_includes Style::PATCHES.keys, name, label
        assert_in_delta Synth::PEAK, samples.map(&:abs).max, 1e-9, label
        assert_operator samples.last.abs, :<, 0.05, label
        assert_operator patch.length, :<=, 1.0, label
      end
    end
  end

  def test_a_glide_rises
    rising = Synth.render(Patch.new(notes: [Note.new(wave: :sine, from: 200, to: 2000, length: 0.2)]))
    crossings = ->(part) { part.each_cons(2).count { |a, b| a.negative? != b.negative? } }

    assert_operator crossings.(rising.last(2000)), :>, crossings.(rising.first(2000))
  end

  def test_an_unknown_wave_is_refused
    assert_raises(ArgumentError) { Synth.render(Patch.new(notes: [Note.new(wave: :kazoo, from: 1, length: 0.01)])) }
  end
end
