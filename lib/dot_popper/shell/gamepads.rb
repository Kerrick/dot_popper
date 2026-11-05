# frozen_string_literal: true

module DotPopper
  module Shell
    # Reads the connected gamepads' left sticks and d-pads each frame.
    # Lota binds controllers from 0.1.3; on an older Lota there is no
    # Lota::Joystick, and every stick is at rest.
    class Gamepads
      # The push of every gamepad's left stick and d-pad, together.
      def stick
        return Presentation::Stick.rest unless defined?(::Lota::Joystick)

        ::Lota::Joystick.joysticks.select(&:gamepad?).sum(Presentation::Stick.rest) { push(it) }
      end

      private

      def push(pad)
        Presentation::Stick.new(x: pad.gamepad_axis(:leftx), y: pad.gamepad_axis(:lefty)) +
          Presentation::Stick.dpad(left: pad.gamepad_down?(:dpleft), right: pad.gamepad_down?(:dpright),
                                   up: pad.gamepad_down?(:dpup), down: pad.gamepad_down?(:dpdown))
      end
    end
  end
end
