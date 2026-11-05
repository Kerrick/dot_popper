# frozen_string_literal: true

module DotPopper
  module Presentation
    # One voice of a sound: a waveform (:sine, :triangle, :square, or
    # :noise) gliding from +from+ to +to+ hertz, starting +start+ seconds
    # in and lasting +length+, rising over +attack+ seconds and dying away
    # after, at +volume+ from 0 to 1.
    class Note < Data.define(:wave, :from, :to, :start, :length, :attack, :volume)
      def initialize(wave:, from:, length:, to: from, start: 0.0, attack: 0.004, volume: 1.0) = super

      def finish = start + length
    end

    # A sound made of notes, played together or in turn.
    class Patch < Data.define(:notes)
      def length = notes.map(&:finish).max
    end

    # Turns patches into samples, from -1 to 1, mono. Every sound in the
    # game is made here when it starts, so there are no sound files.
    module Synth
      RATE = 44_100
      PEAK = 0.9
      TAU = 2 * Math::PI

      module_function

      def render(patch, rate: RATE, seed: 1)
        samples = Array.new((patch.length * rate).ceil, 0.0)
        random = Random.new(seed)
        patch.notes.each { voice(samples, it, rate, random) }
        normalize(samples)
      end

      def voice(samples, note, rate, random)
        first = (note.start * rate).floor
        count = (note.length * rate).floor
        glide = Math.log(note.to.to_f / note.from) / count
        phase = 0.0
        count.times do |i|
          frequency = note.from * Math.exp(glide * i)
          phase = (phase + (frequency / rate)) % 1.0
          samples[first + i] += wave(note.wave, phase, random) * envelope(i, count, note.attack * rate) * note.volume
        end
      end

      def wave(shape, phase, random)
        case shape
        when :sine then Math.sin(TAU * phase)
        when :triangle then 1 - (4 * (phase - 0.5).abs)
        when :square then phase < 0.5 ? 0.6 : -0.6
        when :noise then random.rand(-1.0..1.0)
        else raise ArgumentError, "no waveform #{shape.inspect}"
        end
      end

      # Up quickly, then down along a curve that lands softly at zero, so
      # nothing clicks.
      def envelope(i, count, attack)
        return i / attack if i < attack

        (1 - ((i - attack) / (count - attack)))**2
      end

      def normalize(samples)
        loudest = samples.map(&:abs).max
        return samples if loudest.nil? || loudest.zero?

        gain = PEAK / loudest
        samples.map { it * gain }
      end
    end
  end
end
