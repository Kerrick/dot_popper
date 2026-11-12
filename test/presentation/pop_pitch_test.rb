# frozen_string_literal: true

require_relative "presentation_helper"
require_relative "spectrum"

# Every theme's pop, at every pitch the climb reaches (Show#pop_pitch),
# stays in the band the ordinary pop and the four Halloween pops stay in
# (doc/design/look-and-sound.md, "How high a pop goes"). Measured on what
# the synthesizer makes, the tone without its noise: noise has no pitch
# and is the sound's texture, not where it sits.
class PopPitchTest < Minitest::Test
  include PresentationTest

  REFERENCES = %i[classic ghost jack_o_lantern awake eclipse].freeze
  LOWEST_FUNDAMENTAL = 170.0 # Hz; the references go down to 172
  HIGHEST_FUNDAMENTAL = 800.0 # Hz; the references go up to 791
  HIGHEST_CENTROID = 1050.0 # Hz; the references go up to 1013
  BRIGHT = 1500.0 # Hz
  MOST_ABOVE_BRIGHT = 0.02 # of the tone's energy; the references have at most 0.003

  def test_every_pop_stays_in_the_band_at_the_bottom_and_the_top_of_the_climb
    top = Style::SOUND.pop_highest
    out = spectra.filter_map do |key, spectrum|
      faults = []
      faults << "starts at #{spectrum.fundamental.round} Hz" if spectrum.fundamental < LOWEST_FUNDAMENTAL
      faults << "climbs to #{spectrum.fundamental(top).round} Hz" if spectrum.fundamental(top) > HIGHEST_FUNDAMENTAL
      faults << "its tone centers on #{spectrum.centroid(top).round} Hz at the top" if spectrum.centroid(top) > HIGHEST_CENTROID
      bright = spectrum.share_above(BRIGHT, top)
      faults << "has #{(bright * 100).round(1)}% of its tone over #{BRIGHT.round} Hz at the top" if bright > MOST_ABOVE_BRIGHT
      "#{key} #{faults.join(", ")}" if faults.any?
    end

    assert_empty out
  end

  def test_the_band_is_the_one_the_reference_pops_keep
    spectra.slice(*REFERENCES).each do |key, spectrum|
      [1.0, Style::SOUND.pop_highest].each do |pitch|
        assert_operator spectrum.fundamental(pitch), :>=, LOWEST_FUNDAMENTAL, key
        assert_operator spectrum.fundamental(pitch), :<=, HIGHEST_FUNDAMENTAL, key
        assert_operator spectrum.centroid(pitch), :<=, HIGHEST_CENTROID, key
        assert_operator spectrum.share_above(BRIGHT, pitch), :<=, MOST_ABOVE_BRIGHT / 4, key
      end
    end
  end

  def test_the_climb_is_a_rise_every_ear_hears
    # From the bottom to the top of the climb is more than a major third
    # (four semitones), far past the smallest change an ear tells apart.
    assert_operator Style::SOUND.pop_highest, :>, 2**(4 / 12.0)
  end

  private

  def spectra
    @spectra ||= Style::THEMES.to_h do |theme|
      pop = theme.ordinary? ? Style::PATCHES[:pop] : theme.art.sounds.fetch(:pop)
      tone = Patch.new(notes: pop.notes.reject { it.wave == :noise })
      [theme.key, Spectrum.new(Synth.render(tone), Synth::RATE)]
    end
  end
end
