# frozen_string_literal: true

module DotPopper
  module Shell
    # The device's accelerometer, through Lota::Sensor (Lota 0.1.3 and
    # newer), read only while the game-over pile is there to tilt: it is
    # on from #start to #stop, and off the rest of the time, to spare the
    # battery. A computer without one, or an older Lota, has none, and
    # the first error from the sensor turns it off for good, with a
    # warning, rather than ending the game.
    class Accelerometer
      S = :accelerometer

      def self.present?
        defined?(::Lota::Sensor) && ::Lota::Sensor.sensor?(S) ? true : false
      rescue StandardError => e
        warn "Dot Popper: no tilt, since the accelerometer did not answer (#{e.message})"
        false
      end

      def initialize = @working = self.class.present?

      def present? = @working
      def source = "the accelerometer"

      def start = guard { ::Lota::Sensor.enabled = [S, true] }
      def stop = guard { ::Lota::Sensor.enabled = [S, false] }

      # The latest Presentation::Reading, in g, or nil.
      def reading
        guard do
          return unless ::Lota::Sensor.enabled?(S)

          Presentation::Reading.si(*::Lota::Sensor.data(S))
        end
      end

      private

      def guard
        return unless @working

        yield
      rescue StandardError => e
        warn "Dot Popper: tilting is off, since the accelerometer failed (#{e.message})"
        @working = false
        nil
      end
    end

    # A steady reading in place of an accelerometer, for development:
    # DOT_POPPER_FAKE_TILT=0.6,0 holds a tablet tilted sideways (main.rb).
    class FakeAccelerometer < Data.define(:steady)
      def present? = true
      def source = "a fake reading (DOT_POPPER_FAKE_TILT=#{steady.x},#{steady.y})"
      def start = nil
      def stop = nil
      def reading = steady
    end
  end
end
