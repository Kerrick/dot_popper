# frozen_string_literal: true

# Where a sound's energy sits, from its samples, so a test can hear in
# numbers. The power spectrum of the first SIZE samples (padded with
# silence), by a plain radix-2 FFT. +pitch+ scales every frequency, as
# OpenAL's pitch does by playing the samples faster.
class Spectrum
  SIZE = 8192

  def initialize(samples, rate)
    @rate = rate
    padded = samples.first(SIZE) + Array.new([SIZE - samples.size, 0].max, 0.0)
    @power = fft(padded.map { Complex(it, 0.0) }).first(SIZE / 2).map(&:abs2)
  end

  # The lowest frequency carrying at least a fifth of the loudest band's
  # energy (bands of five bins, about 27 Hz): the sound's fundamental, as
  # an ear takes the lowest strong partial.
  def fundamental(pitch = 1.0)
    bands = @power.each_cons(5).map(&:sum)
    loudest = bands.max
    hz(bands.index { it >= loudest / 5.0 } + 2, pitch)
  end

  # The energy-weighted mean frequency.
  def centroid(pitch = 1.0)
    total = @power.sum
    @power.each_with_index.sum { |power, bin| power * hz(bin, pitch) } / total
  end

  # The share of the energy above +limit+ hertz.
  def share_above(limit, pitch = 1.0)
    @power.each_with_index.sum { |power, bin| hz(bin, pitch) > limit ? power : 0.0 } / @power.sum
  end

  private

  def hz(bin, pitch) = bin * @rate.to_f / SIZE * pitch

  # An iterative radix-2 FFT of +values+ (a power of two of them).
  def fft(values)
    n = values.size
    out = Array.new(n)
    bits = n.bit_length - 1
    n.times { |i| out[i.to_s(2).rjust(bits, "0").reverse.to_i(2)] = values[i] }
    span = 2
    while span <= n
      step = Complex.polar(1.0, -2 * Math::PI / span)
      (0...n).step(span) do |first|
        turn = Complex(1.0, 0.0)
        (span / 2).times do |k|
          a = out[first + k]
          b = out[first + k + (span / 2)] * turn
          out[first + k] = a + b
          out[first + k + (span / 2)] = a - b
          turn *= step
        end
      end
      span *= 2
    end
    out
  end
end
