# frozen_string_literal: true

module DotPopper
  module Shell
    # Lets the player play with the game-over pile: tilt the tablet, or
    # push a gamepad's right stick, and the dots roll that way; shake it,
    # and they jump. The rules are frozen by then, so none of it can touch
    # a score. Presentation::Tilt does the deciding; this feeds it the
    # accelerometer, the stick and the screen's orientation each frame,
    # and carries out what it asks on the Pile.
    #
    # It hears the rules' events (Game#subscribe), after the Pile does.
    # The accelerometer is on only while a pile is there. With neither an
    # accelerometer nor a pushed stick, it never touches the pile, which
    # falls as it always has.
    class Tilting
      STICK = "the gamepad's right stick"

      # The light line Game Over shows, saying how to play, or nil.
      attr_reader :hint

      def initialize(pile:, gamepads:, accelerometer:, look:, hint:, device:, turns:, random: Random.new)
        @pile = pile
        @gamepads = gamepads
        @accelerometer = accelerometer
        @look = look
        @hints = hint
        @device = device
        @turns = turns
        @random = random
        @tilt = @hint = nil
      end

      def call(event)
        case event
        when Events::RoundEnded then begin_pile
        when Events::RoundStarted, Events::TitleShown then end_pile
        end
      end

      def update(seconds)
        return unless @tilt && @pile.falling?

        reading = @accelerometer.reading if @accelerometer.present?
        stick = @gamepads.right_stick
        return unless @tilted || reading || !stick.shaped(@look.dead_zone, 1.0).rest?

        @tilted = true
        @tilt.orientation = orientation
        apply(@tilt.update(seconds, reading:, stick:))
      end

      private

      def begin_pile
        @tilt = Presentation::Tilt.new(@look, orientation:)
        @tilted = false
        @accelerometer.start if @accelerometer.present?
        sources = [(@accelerometer.source if @accelerometer.present?), (STICK if @gamepads.any?)].compact
        puts "Dot Popper: tilt from #{sources.empty? ? "none" : sources.join(" and ")}"
        @hint = @hints.offer(gamepad: @gamepads.any?, accelerometer: @accelerometer.present?, device: @device)
      end

      def end_pile
        @accelerometer.stop if @tilt && @accelerometer.present?
        @tilt = @hint = nil
      end

      def apply(step)
        @pile.tilt(step.pull, wake: step.wake)
        return unless step.kick.positive?

        @pile.throw_balls { |radius| @look.fling.velocity(step.pull, step.kick, radius, @random) }
      end

      # How the screen sits on the device, on a phone or tablet whose
      # screen turns; a computer's screen is always as its sensor is.
      def orientation
        @turns ? ::Lota::Window.display_orientation : :portrait
      rescue StandardError
        :portrait
      end
    end
  end
end
